## Start container
docker-compose up

## rails console
docker-compose exec app rails c

## log into container then run rake
```
docker exec -it lcbo-api_app_1 /bin/bash
rake cron
```

## run from docker compose
```
docker-compose exec app rake cron
```
