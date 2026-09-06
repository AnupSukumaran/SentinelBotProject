import RPi.GPIO as GPIO
import paho.mqtt.client as mqtt
import json, time, threading, datetime

IN1, IN2, ENA = 17, 27, 12
IN3, IN4, ENB = 22, 23, 13
TRIG, ECHO = 24, 25

# Must match Constants.Control.watchdogTimeoutSeconds in the iOS app.
# The app republishes the joystick position at 20 Hz while a finger is down,
# so anything longer than a couple of frames means the link is gone.
WATCHDOG_TIMEOUT = 0.5

# Obstacle distance (cm) below which the motors are cut.
OBSTACLE_STOP_CM = 20

GPIO.setmode(GPIO.BCM)
GPIO.setup([IN1, IN2, IN3, IN4], GPIO.OUT)
GPIO.setup(ENA, GPIO.OUT)
GPIO.setup(ENB, GPIO.OUT)
GPIO.setup(TRIG, GPIO.OUT)
GPIO.setup(ECHO, GPIO.IN)

pwm_a = GPIO.PWM(ENA, 1000)
pwm_b = GPIO.PWM(ENB, 1000)
pwm_a.start(0)
pwm_b.start(0)

estopped = False
current_mode = "manual"

# Watchdog state. `last_move_at` is only bumped by commands arriving from
# outside; internal stops deliberately do not touch it, so a stop can never
# look like fresh input.
_state_lock = threading.Lock()
last_move_at = 0.0
motors_running = False


def _apply(left, right):
    """Low-level motor drive. Does not touch watchdog state."""
    global motors_running
    GPIO.output(IN1, left > 0)
    GPIO.output(IN2, left < 0)
    GPIO.output(IN3, right > 0)
    GPIO.output(IN4, right < 0)
    pwm_a.ChangeDutyCycle(abs(left) * 70)
    pwm_b.ChangeDutyCycle(abs(right) * 70)
    motors_running = (left != 0 or right != 0)


def set_motors(linear, angular):
    """Drive in response to an external command, and pet the watchdog."""
    global last_move_at
    left = max(-1, min(1, linear + angular))
    right = max(-1, min(1, linear - angular))
    with _state_lock:
        last_move_at = time.monotonic()
        _apply(left, right)


def stop_motors():
    with _state_lock:
        _apply(0, 0)


def watchdog_loop():
    """Cut the motors if no move command has arrived recently.

    This is the safety property that makes untethered operation acceptable:
    if the app crashes, the phone leaves Wi-Fi, or the broker dies while the
    joystick is held, the robot stops on its own instead of driving away.
    """
    while True:
        with _state_lock:
            stale = motors_running and (time.monotonic() - last_move_at) > WATCHDOG_TIMEOUT
            if stale:
                _apply(0, 0)
        if stale:
            print("watchdog: no move command for %.1fs - motors stopped" % WATCHDOG_TIMEOUT)
        time.sleep(0.05)


def read_distance():
    """One HC-SR04 reading in cm, or None if the echo never came back."""
    GPIO.output(TRIG, False)
    time.sleep(0.06)
    GPIO.output(TRIG, True)
    time.sleep(0.00001)
    GPIO.output(TRIG, False)
    timeout = time.time() + 0.04
    start = time.time()
    while GPIO.input(ECHO) == 0:
        start = time.time()
        if time.time() > timeout:
            return None
    timeout = time.time() + 0.04
    end = time.time()
    while GPIO.input(ECHO) == 1:
        end = time.time()
        if time.time() > timeout:
            return None
    return round((end - start) * 17150, 1)


def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def on_connect(client, userdata, flags, reason_code, properties=None):
    """Subscribe here, not once at startup.

    paho reconnects automatically inside loop_forever(), but subscriptions do
    not survive the reconnect. Subscribing from the connect callback means a
    broker restart no longer silently deafens the robot.
    """
    print("connected to broker (rc=%s) - subscribing" % reason_code)
    client.subscribe("sentinelbot/cmd/#")
    client.publish("sentinelbot/presence/robot", "online", retain=True)


def on_message(client, userdata, msg):
    global estopped, current_mode
    topic = msg.topic

    # E-stop is handled before JSON parsing, because clearing it is signalled
    # by an EMPTY retained payload (that is how the iOS app deletes the
    # retained message from the broker) and an empty body is not valid JSON.
    if topic == "sentinelbot/cmd/estop":
        if len(msg.payload) == 0:
            estopped = False
            print("E-STOP cleared")
        else:
            estopped = True
            stop_motors()
            print("E-STOP")
        return

    try:
        payload = json.loads(msg.payload.decode())
    except (ValueError, UnicodeDecodeError):
        return

    if topic == "sentinelbot/cmd/move":
        if estopped:
            return
        set_motors(payload.get("linear", 0), payload.get("angular", 0))

    elif topic == "sentinelbot/cmd/mode":
        mode = payload.get("mode", "manual")
        if mode == "manual":
            estopped = False
        current_mode = mode
        stop_motors()
        client.publish("sentinelbot/status/mode",
                       json.dumps({"mode": current_mode, "timestamp": now_iso()}))


def telemetry_loop(client):
    while True:
        try:
            dist = read_distance()
            if dist is None:
                print("sensor: no echo (check wiring / nothing in range)")
            else:
                client.publish("sentinelbot/status/distance",
                               json.dumps({"distanceMeters": round(dist / 100, 2),
                                           "timestamp": now_iso()}))
                if dist < OBSTACLE_STOP_CM and motors_running:
                    stop_motors()
                    print("Obstacle at %scm - motors stopped" % dist)
        except Exception as e:
            print("telemetry error: %r" % (e,))

        # NOTE: these are placeholder constants. There is no battery monitoring
        # hardware on this robot yet, so the app's low-battery warnings can
        # never fire. Wire up a real divider before trusting them.
        client.publish("sentinelbot/status/battery",
                       json.dumps({"voltageVolts": 12.0, "percentage": 0.85,
                                   "isCharging": False, "timestamp": now_iso()}))
        time.sleep(1)


client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.on_connect = on_connect
client.on_message = on_message

# Last Will: if this process or the Pi dies, the broker tells everyone the
# robot is offline. Without it the retained "online" outlives the robot.
client.will_set("sentinelbot/presence/robot", "offline", retain=True)

client.connect("localhost", 1883)

threading.Thread(target=telemetry_loop, args=(client,), daemon=True).start()
threading.Thread(target=watchdog_loop, daemon=True).start()

print("SentinelBot running (watchdog %.1fs). Ctrl+C to stop." % WATCHDOG_TIMEOUT)
try:
    client.loop_forever()
except KeyboardInterrupt:
    stop_motors()
    GPIO.cleanup()
    print("Stopped.")
