Run this command to generate initdb.sql:

```
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --mysql > initdb.sql
```

Run this command to create the database in the MySQL container:

```
mysql -u guacamole_user -p guacamole_db < initdb.sql
```
