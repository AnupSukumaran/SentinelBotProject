from flask import Flask, Response
from picamera2 import Picamera2
import io, threading, time

app = Flask(__name__)
camera = Picamera2()
camera.configure(camera.create_video_configuration(main={"size": (640, 480)}))
camera.start()

frame_lock = threading.Lock()
latest_frame = b""

def capture_loop():
    global latest_frame
    while True:
        buf = io.BytesIO()
        camera.capture_file(buf, format="jpeg")
        with frame_lock:
            latest_frame = buf.getvalue()
        time.sleep(0.05)

def generate():
    while True:
        with frame_lock:
            frame = latest_frame
        if frame:
            yield (b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + frame + b"\r\n")
        time.sleep(0.05)

@app.route("/stream")
def stream():
    return Response(generate(), mimetype="multipart/x-mixed-replace; boundary=frame")

t = threading.Thread(target=capture_loop, daemon=True)
t.start()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
