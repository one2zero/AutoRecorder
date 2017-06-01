# AutoRecorder
### 1.编译后的可执行程序拷贝到 /usr/local/bin
### 2.启动命令行服务 AutoRecord -u xxxxxxxxxxxxxxxxxx
### 3.通过其他服务发送指令到本机的9000端口，启动或者停止录制服务 
以curl为例：<br>
启动 curl -X POST '-H "Content-Type: application/json"' \-d "/Users/<username>/Desktop/test.mov" http://127.0.0.1:9000/start<br>
停止 curl -X GET '-H "Content-Type: application/json"' http://127.0.0.1:9000/stop
