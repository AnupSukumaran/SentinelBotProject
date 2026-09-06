"""
SentinelBot - First Motor Test
This script tests both motors by spinning them forward briefly.
"""

import RPi.GPIO as GPIO
import time

# Pin definitions (using BCM/GPIO numbering, NOT physical pin numbers)
# Motor A (left motor)
MOTOR_A_IN1 = 17
MOTOR_A_IN2 = 27
MOTOR_A_ENA = 12  # PWM pin for speed

# Motor B (right motor)
MOTOR_B_IN3 = 22
MOTOR_B_IN4 = 23
MOTOR_B_ENB = 13  # PWM pin for speed

# Setup GPIO
GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)

# Set all motor control pins as outputs
GPIO.setup(MOTOR_A_IN1, GPIO.OUT)
GPIO.setup(MOTOR_A_IN2, GPIO.OUT)
GPIO.setup(MOTOR_A_ENA, GPIO.OUT)
GPIO.setup(MOTOR_B_IN3, GPIO.OUT)
GPIO.setup(MOTOR_B_IN4, GPIO.OUT)
GPIO.setup(MOTOR_B_ENB, GPIO.OUT)

# Setup PWM on the enable pins (1000 Hz frequency)
pwm_a = GPIO.PWM(MOTOR_A_ENA, 1000)
pwm_b = GPIO.PWM(MOTOR_B_ENB, 1000)

# Start PWM at 0% duty cycle (motors stopped)
pwm_a.start(0)
pwm_b.start(0)

print("SentinelBot motor test starting...")
print("Watch the wheels - they should spin for 2 seconds.")

try:
    # === Test 1: Both motors forward ===
    print("\nTest 1: Both motors FORWARD")
    
    # Motor A forward
    GPIO.output(MOTOR_A_IN1, GPIO.HIGH)
    GPIO.output(MOTOR_A_IN2, GPIO.LOW)
    
    # Motor B forward
    GPIO.output(MOTOR_B_IN3, GPIO.HIGH)
    GPIO.output(MOTOR_B_IN4, GPIO.LOW)
    
    # Set speed to 70%
    pwm_a.ChangeDutyCycle(70)
    pwm_b.ChangeDutyCycle(70)
    
    time.sleep(2)
    
    # === Stop ===
    print("Stopping motors")
    pwm_a.ChangeDutyCycle(0)
    pwm_b.ChangeDutyCycle(0)
    
    time.sleep(1)
    
    # === Test 2: Both motors backward ===
    print("\nTest 2: Both motors BACKWARD")
    
    # Motor A backward
    GPIO.output(MOTOR_A_IN1, GPIO.LOW)
    GPIO.output(MOTOR_A_IN2, GPIO.HIGH)
    
    # Motor B backward
    GPIO.output(MOTOR_B_IN3, GPIO.LOW)
    GPIO.output(MOTOR_B_IN4, GPIO.HIGH)
    
    pwm_a.ChangeDutyCycle(70)
    pwm_b.ChangeDutyCycle(70)
    
    time.sleep(2)
    
    # === Final stop ===
    print("\nTest complete. Stopping all motors.")
    pwm_a.ChangeDutyCycle(0)
    pwm_b.ChangeDutyCycle(0)

except KeyboardInterrupt:
    print("\nTest interrupted by user")

finally:
    # Clean up GPIO
    pwm_a.stop()
    pwm_b.stop()
    GPIO.cleanup()
    print("GPIO cleaned up. Goodbye!")
