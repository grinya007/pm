Package monitoring

```
docker build -t ag/pm .
docker run -dit -p 3000:3000 -v /var/log/zypp:/zypp -e PM_LOG=/zypp/history ag/pm
```
