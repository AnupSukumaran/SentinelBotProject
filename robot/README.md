# SentinelBot — robot side

The code that actually runs on the Raspberry Pi, recovered from the Pi itself on
2026-09-06 and committed here so it stops living on a single SD card.

> **This supersedes the root `README.md`'s description of the robot.** There is no ROS
> on this Pi, and no `mqtt_bridge_node.py`. The robot is three plain Python scripts.

## Hardware

Raspberry Pi (Pi OS 2025-12-04), hostname `Sentinelbot`, user `pi`.

| Function | GPIO (BCM) |
|---|---|
| Motor A (left) IN1 / IN2 / ENA | 17 / 27 / 12 |
| Motor B (right) IN3 / IN4 / ENB | 22 / 23 / 13 |
| HC-SR04 TRIG / ECHO | 24 / 25 |

PWM runs at 1 kHz; duty cycle is capped at 70 % of the commanded magnitude.

## Files

| File | Role |
|---|---|
| `sentinel_robot.py` | The robot. MQTT client, motor control, ultrasonic telemetry. Runs as `sentinelbot.service`. |
| `camera_stream.py` | Flask + Picamera2 MJPEG server on `:8080/stream`, 640×480. Runs as `sentinelcam.service`. |
| `test_sensor.py` | Standalone one-shot HC-SR04 reading, prints cm. Bench diagnostic. |
| `motor_test.py` | Standalone motor exercise — both wheels forward 2 s, back 2 s. Bench diagnostic. |
| `systemd/` | Unit files as installed in `/etc/systemd/system/`. Both `Restart=always`. |
| `requirements-frozen.txt` | `pip3 freeze` from the Pi as of 2026-09-06. |

## Deploying a change

These files are the source of truth; the Pi holds working copies at `/home/pi`.

```sh
scp robot/sentinel_robot.py pi@sentinelbot.local:/home/pi/
ssh pi@sentinelbot.local 'sudo systemctl restart sentinelbot'
```

## MQTT contract, as implemented

Subscribes to `sentinelbot/cmd/#`, publishes `sentinelbot/status/*`. Verified against
live traffic — keys are camelCase and timestamps are ISO-8601 strings, matching the
iOS `Codable` models exactly.

| Topic | Direction | Notes |
|---|---|---|
| `cmd/move` | in | `{linear, angular}` each −1…1, mixed to `left = linear + angular`, `right = linear − angular` |
| `cmd/mode` | in | `{mode}`; `"manual"` also clears the e-stop flag |
| `cmd/estop` | in | any parseable JSON sets `estopped = True` |
| `status/distance` | out | `{distanceMeters}` at 1 Hz |
| `status/battery` | out | **hardcoded constants — see below** |
| `status/mode` | out | echoed only on mode change |
| `presence/robot` | out | retained `"online"` at startup |

## Known defects

Found by reading the code on 2026-09-06. None are fixed yet.

1. **No motor watchdog.** `set_motors()` has no timeout. If the app quits, the phone
   drops Wi-Fi, or the broker dies mid-move, the wheels keep turning indefinitely.
   The iOS side publishes at 20 Hz and sends an explicit stop on release, and
   `Constants.Control.watchdogTimeoutSeconds` documents a 0.5 s robot-side watchdog —
   which does not exist. **This is the blocking safety defect for untethered operation.**

2. **The app's "clear e-stop" does nothing.** The app clears by publishing an empty
   retained payload; `on_message` calls `json.loads` on it, throws, and returns early.
   `estopped` stays `True` until a `cmd/mode` of `"manual"` arrives or the service
   restarts.

3. **Battery telemetry is fake.** `voltageVolts: 12.0, percentage: 0.85` are literals.
   There is no battery monitoring hardware or code, so the app's low-battery warnings
   can never fire.

4. **No odometry.** Nothing publishes `status/position`, so the app's map has no source.

5. **Subscriptions are not restored on reconnect.** `subscribe()` is called once before
   `loop_forever()` rather than from an `on_connect` handler. After a broker restart the
   client reconnects but silently stops receiving commands.

6. **No Last Will.** If the Pi dies, the retained `presence/robot` stays `"online"`.
   (Separately, the iOS app sets *its own* LWT on that same topic, so the app
   disconnecting marks the *robot* offline — wrong side.)

7. **Obstacle stop fights the joystick.** `telemetry_loop` calls `stop_motors()` whenever
   the reading is under 20 cm, once a second, regardless of mode. With the sensor
   currently reading 4–10 cm, the motors are being cut every second.

8. **Bare `except: pass`** around the whole telemetry body hides sensor faults —
   `read_distance()` returns `None` on timeout and the resulting `TypeError` is
   swallowed, so a dead sensor looks like silence rather than an error.
