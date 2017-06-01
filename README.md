# AutoRecorder<br>
使用AVFoundation框架对通过USB连接到Mac上的iOS设备录屏

### 1.编译后的可执行程序拷贝到 /usr/local/bin/
### 2.在命令行启动服务 AutoRecord -u xxxxxxxxxxxxxxxxxx
-u iOS设备的uuid<br>
-t 作为可选参数，选择0时通过file形式录制；选择1时，通过data帧形式录制。默认为0

### 3.通过其他服务发送指令到本机的9000端口，启动或者停止录制服务 
#### 以curl为例：<br>
##### 启动 curl -X POST '-H "Content-Type: application/json"' \-d "/Users/xxxx/Desktop/test.mov" http://127.0.0.1:9000/start<br>
"/Users/xxxx/Desktop/test.mov"为录制文件的存储路径<br>
##### 停止 curl -X GET '-H "Content-Type: application/json"' http://127.0.0.1:9000/stop
