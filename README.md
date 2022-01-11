#创建service-a服务的镜像
#golang安装包和service-文件，太大，占用空间，删除了
#进入dockerfile-service目录
 docker build -t=zwstest/servicedemon5 .
docker login https://hub.docker.com/
 docker push zwstest/servicedemon5:latest

#创建腾讯云TKE-实现代码
#进入tke-create目录

#开发helm chart ，将服务推送到远程TKE 
#安装kubectl
#将提供的k8s集群config，jihu-handson-tke-kubeconfig.zhouweishuang.yaml配置到/root/.kube/config
#helm create zws-service-01
#修改 values和template/deployment.yaml文件
#helm 语法检查：  helm lint --strict  zws-service-01  
#查看helm安装最终会生成的yaml文件
# helm install zwstest  --dry-run --debug  zws-service-01
# helm 打包：helm package zws-service-01
# helm 安装： helm install zws-service -n service-zhouweishuang zws-service-01-0.1.0.tgz

