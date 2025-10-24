# PointCloudSDK
A point cloud processing SDK for iOS



### 1. How to Integrate the SDK

##### 	1.Open Xcode → File → Add Package Dependencies

 ##### 	2.Enter the repository URL:

```
https://github.com/TonyTaoLiang/PointCloudSDK.git
```

##### 	3.Select the version rule:

```
Up to Next Major Version (from 1.0.0)
```

##### 	4. Click "Add Package"



### 2.How to Use the SDK

##### 	1.Import the SDK 

```
import PointCloudSDK
```

##### 	2.Start Connection

```
PointCloudManager.shared.connect(sn: "30224014", host: "192.168.201.1", port: 1883)
```

##### 	3.Start Capture

```
PointCloudManager.shared.startCapture { result in
                    switch result {
                    case .success:
                        print("StartCapture Success")
                    case .failure(let error):
                        print("StartCapture Failed: \(error)")
                    }
                }
```

##### 	4.Stop Capture

```
PointCloudManager.shared.stopCapture { result in
                    switch result {
                    case .success:
                        print("StopCapture Success")
                    case .failure(let error):
                        print("StopCapture Failed: \(error)")
                    }
                }
```

##### 	5.Point Cloud View

```
PointCloudManager.shared.createPointCloudView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
```

​	Please refer to the provided SDKDemo for details.



### 3.Important Notes

The mobile phone must first connect to the device's hotspot (e.g., Rayzoom G200) before initiating the connection.
