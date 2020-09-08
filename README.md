# locust_terraform

## Architecture
![locust_architecture](https://github.com/wkm2/locust_terraform/blob/master/locust_architecture.png)

## Setting
Replace the locust_dashboard_client_ip variable in locustfile.py with your global IP
```
variable "locust_dashboard_client_ip" {
  default = "xxx.xxx.xxx.xxx/xx"
}
```

## Deploy
```
$ terraform apply
$ aws ssm send-command --document-name "locust-master-command" --targets '[{"Key":"tag:Name","Values":["locust-master"]}]'
$ aws ssm send-command --document-name "locust-worker-command" --targets '[{"Key":"tag:aws:autoscaling:groupName","Values":["locust-worker"]}]'
```
