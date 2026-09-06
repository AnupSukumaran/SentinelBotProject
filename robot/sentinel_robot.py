import RPi.GPIO as GPIO
import paho.mqtt.client as mqtt
import json, time, threading, datetime

IN1, IN2, ENA = 17, 27, 12
IN3, IN4, ENB = 22, 23, 13
TRIG, ECHO = 24, 25

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

def set_motors(linear, angular):
    left  = max(-1, min(1, linear + angular))
    right = max(-1, min(1, linear - angular))
    GPIO.output(IN1, left  > 0)
    GPIO.output(IN2, left  < 0)
    GPIO.output(IN3, right > 0)
    GPIO.output(IN4, right < 0)
    pwm_a.ChangeDutyCycle(abs(left)  * 70)
    pwm_b.ChangeDutyCycle(abs(right) * 70)

def stop_motors():
    set_motors(0, 0)

def read_distance():
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

def on_message(client, userdata, msg):
    global estopped, current_mode
    topic = msg.topic
    try:
        payload = json.loads(msg.payload.decode())
    except:
        return
    if topic == "sentinelbot/cmd/estop":
        estopped = True
        stop_motors()
        print("E-STOP")
    elif topic == "sentinelbot/cmd/move":
        if estopped: return
        set_motors(payload.get("linear", 0), payload.get("angular", 0))
    elif topic == "sentinelbot/cmd/mode":
        mode = payload.get("mode", "manual")
        if mode == "manual":
            estopped = False
        current_mode = mode
        client.publish("sentinelbot/status/mode",
            json.dumps({"mode": current_mode, "timestamp": now_iso()}))

def telemetry_loop(client):
    while True:
        try:
            dist = read_distance()
            client.publish("sentinelbot/status/distance",
                json.dumps({"distanceMeters": round(dist / 100, 2), "timestamp": now_iso()}))
            if dist < 20:
                stop_motors()
                print("Obstacle at " + str(dist) + "cm - motors stopped")
        except:
            pass
        client.publish("sentinelbot/status/battery",
            json.dumps({"voltageVolts": 12.0, "percentage": 0.85,
                        "isCharging": False, "timestamp": now_iso()}))
        time.sleep(1)

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.on_message = on_message
client.connect("localhost", 1883)
client.subscribe("sentinelbot/cmd/#")
client.publish("sentinelbot/presence/robot", "online", retain=True)

t = threading.Thread(target=telemetry_loop, args=(client,), daemon=True)
t.start()

print("SentinelBot running. Ctrl+C to stop.")
try:
    client.loop_forever()
except KeyboardInterrupt:
    stop_motors()
    GPIO.cleanup()
    print("Stopped.")
