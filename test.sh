#!/bin/bash
set -eo pipefail

### Cleanup hook: Automatically removes container and network on script exit or interrupt
cleanup() {
  echo "INFO: Cleaning up Docker containers and networks..."
  docker rm -f mysql 2>/dev/null || true
  docker network rm test-network 2>/dev/null || true
}
trap cleanup EXIT

### Initial setup phase
echo "INFO: Starting a MySQL database server for tests"
docker network create -d bridge test-network 2>/dev/null || true

docker run --name mysql --network=test-network --hostname mysql \
  -e MYSQL_ROOT_PASSWORD=P@ssw0rd \
  -v "$(pwd)":/scripts \
  -d mysql:8.0-debian

echo "INFO: Waiting for database server to initialize..."
until docker exec mysql mysqladmin ping -u root -pP@ssw0rd --silent 2>/dev/null; do
  echo "Waiting for MySQL container to become ready..."
  sleep 3
done

echo "INFO: Creating a database for test"
docker exec mysql mysql -u root -pP@ssw0rd -e "CREATE DATABASE IF NOT EXISTS ShopDB;"
docker exec mysql sh -c 'mysql -u root -pP@ssw0rd ShopDB < /scripts/test-queries/1-create-database.sql'

### v0.0.1
echo "INFO: Running the database migration 0.0.1"
docker run --network=test-network -v "$(pwd)":/repos --workdir /repos/ -e INSTALL_MYSQL=true \
    -e LIQUIBASE_COMMAND_USERNAME=root \
    -e LIQUIBASE_COMMAND_PASSWORD=P@ssw0rd \
    -e LIQUIBASE_COMMAND_URL=jdbc:mysql://mysql:3306/ShopDB \
    liquibase/liquibase update --changelog-file=task.sql --labels="0.0.1"

echo "INFO: Tagging a database version (0.0.1)"
docker run --network=test-network -v "$(pwd)":/repos --workdir /repos/ -e INSTALL_MYSQL=true \
    -e LIQUIBASE_COMMAND_USERNAME=root \
    -e LIQUIBASE_COMMAND_PASSWORD=P@ssw0rd \
    -e LIQUIBASE_COMMAND_URL=jdbc:mysql://mysql:3306/ShopDB \
    liquibase/liquibase --changelog-file=task.sql tag 0.0.1

echo "INFO: Running the tests for database schema version 0.0.1"
docker exec mysql sh -c 'mysql -u root -pP@ssw0rd ShopDB < /scripts/test-queries/2-test-0.0.1.sql' > log.txt
errors=$(grep "^Error" log.txt || true)
if [ -n "$errors" ]; then echo "$errors" && exit 1; fi

### v0.0.2 deployment 
echo "INFO: Running the database migration 0.0.2"
docker run --network=test-network -v "$(pwd)":/repos --workdir /repos/ -e INSTALL_MYSQL=true \
    -e LIQUIBASE_COMMAND_USERNAME=root \
    -e LIQUIBASE_COMMAND_PASSWORD=P@ssw0rd \
    -e LIQUIBASE_COMMAND_URL=jdbc:mysql://mysql:3306/ShopDB \
    liquibase/liquibase update --changelog-file=task.sql --labels="0.0.2"

echo "INFO: Tagging a database version (0.0.2)"
docker run --network=test-network -v "$(pwd)":/repos --workdir /repos/ -e INSTALL_MYSQL=true \
    -e LIQUIBASE_COMMAND_USERNAME=root \
    -e LIQUIBASE_COMMAND_PASSWORD=P@ssw0rd \
    -e LIQUIBASE_COMMAND_URL=jdbc:mysql://mysql:3306/ShopDB \
    liquibase/liquibase --changelog-file=task.sql tag 0.0.2

echo "INFO: Running the tests for database schema version 0.0.2"
docker exec mysql sh -c 'mysql -u root -pP@ssw0rd ShopDB < /scripts/test-queries/3-test-0.0.2.sql' > log.txt
errors=$(grep "^Error" log.txt || true)
if [ -n "$errors" ]; then echo "$errors" && exit 1; fi

### v0.0.3 deployment 
echo "INFO: Running the database migration 0.0.3"
docker run --network=test-network -v "$(pwd)":/repos --workdir /repos/ -e INSTALL_MYSQL=true \
    -e LIQUIBASE_COMMAND_USERNAME=root \
    -e LIQUIBASE_COMMAND_PASSWORD=P@ssw0rd \
    -e LIQUIBASE_COMMAND_URL=jdbc:mysql://mysql:3306/ShopDB \
    liquibase/liquibase update --changelog-file=task.sql --labels="0.0.3"

echo "INFO: Tagging a database version (0.0.3)"
docker run --network=test-network -v "$(pwd)":/repos --workdir /repos/ -e INSTALL_MYSQL=true \
    -e LIQUIBASE_COMMAND_USERNAME=root \
    -e LIQUIBASE_COMMAND_PASSWORD=P@ssw0rd \
    -e LIQUIBASE_COMMAND_URL=jdbc:mysql://mysql:3306/ShopDB \
    liquibase/liquibase --changelog-file=task.sql tag 0.0.3

echo "INFO: Running the tests for database schema version 0.0.3"
docker exec mysql sh -c 'mysql -u root -pP@ssw0rd ShopDB < /scripts/test-queries/4-test-0.0.3.sql' > log.txt
errors=$(grep "^Error" log.txt || true)
if [ -n "$errors" ]; then echo "$errors" && exit 1; fi

### rollback to v0.0.2
echo "INFO: rolling back to database version 0.0.2"
docker run --network=test-network -v "$(pwd)":/repos --workdir /repos/ -e INSTALL_MYSQL=true \
    -e LIQUIBASE_COMMAND_USERNAME=root \
    -e LIQUIBASE_COMMAND_PASSWORD=P@ssw0rd \
    -e LIQUIBASE_COMMAND_URL=jdbc:mysql://mysql:3306/ShopDB \
    liquibase/liquibase --changelog-file=task.sql rollback 0.0.2

echo "INFO: Running the tests for database schema version 0.0.2"
docker exec mysql sh -c 'mysql -u root -pP@ssw0rd ShopDB < /scripts/test-queries/3-test-0.0.2.sql' > log.txt
errors=$(grep "^Error" log.txt || true)
if [ -n "$errors" ]; then echo "$errors" && exit 1; fi

### rollback to v0.0.1 
echo "INFO: rolling back to database version 0.0.1"
docker run --network=test-network -v "$(pwd)":/repos --workdir /repos/ -e INSTALL_MYSQL=true \
    -e LIQUIBASE_COMMAND_USERNAME=root \
    -e LIQUIBASE_COMMAND_PASSWORD=P@ssw0rd \
    -e LIQUIBASE_COMMAND_URL=jdbc:mysql://mysql:3306/ShopDB \
    liquibase/liquibase --changelog-file=task.sql rollback 0.0.1

echo "INFO: Running the tests for database schema version 0.0.1"
docker exec mysql sh -c 'mysql -u root -pP@ssw0rd ShopDB < /scripts/test-queries/2-test-0.0.1.sql' > log.txt
errors=$(grep "^Error" log.txt || true)
if [ -n "$errors" ]; then echo "$errors" && exit 1; fi