# locust_terraform

## Architecture
![locust_architecture](https://github.com/wkm2/locust_terraform/blob/master/locust_architecture.png)

## Deploy
```
$ terraform apply
$ aws ssm send-command --document-name "locust-master-command" --targets '[{"Key":"tag:Name","Values":["locust-master"]}]'
$ aws ssm send-command --document-name "locust-worker-command" --targets '[{"Key":"tag:aws:autoscaling:groupName","Values":["locust-worker"]}]'
```
