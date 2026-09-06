import RPi.GPIO as GPIO
import time

TRIG, ECHO = 24, 25
GPIO.setmode(GPIO.BCM)
GPIO.setup(TRIG, GPIO.OUT)
GPIO.setup(ECHO, GPIO.IN)

GPIO.output(TRIG, False)
time.sleep(0.5)

GPIO.output(TRIG, True)
time.sleep(0.00001)
GPIO.output(TRIG, False)

start = time.time()
while GPIO.input(ECHO) == 0:
    start = time.time()

end = time.time()
while GPIO.input(ECHO) == 1:
    end = time.time()

distance = (end - start) * 17150
print(f'Distance: {round(distance, 1)} cm')
GPIO.cleanup()
