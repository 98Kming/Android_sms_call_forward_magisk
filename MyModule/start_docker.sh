PATH=/data/data/com.termux/files/usr/bin:$PATH

# 开启远程访问
sshd

# 目录挂载
sudo mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup
sudo dockerd --iptables=false

#sudo data/data/com.termux/files/home/docker-compose -f /data/data/com.termux/files/home/docker-compose-env.yml down
# 容器启动
#sudo /data/data/com.termux/files/home/docker-compose -f /data/data/com.termux/files/home/docker-compose-env.yml up -d
