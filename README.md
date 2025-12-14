# Infraestructura LEMP en 4 Capas - Gestión de Usuarios

**Autor:** Guillermo Álvarez Franganillo  
**Curso:** ASIR-2  
**Proyecto:** Pila LEMP con Alta Disponibilidad

---

## Índice

1. [Resumen de la Infraestructura](#resumen-de-la-infraestructura)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Explicación del Código](#explicación-del-código)
4. [Problemas Comunes](#problemas-comunes)
5. [Pruebas de Funcionamiento](#pruebas-de-funcionamiento)
6. [Despliegue](#despliegue)

---

## Resumen de la Infraestructura

Este proyecto monta una infraestructura LEMP (Linux, Nginx, MySQL, PHP) distribuida en 4 capas con alta disponibilidad para gestionar una aplicación CRUD de usuarios. La idea es tener redundancia en todos los niveles: si falla un servidor web, el otro sigue funcionando; si falla una base de datos, la otra toma el relevo.

### Componentes principales:

- **Capa 1 - Balanceo Web**: Un Nginx que reparte el tráfico entre los dos servidores web
- **Capa 2 - Servidores Web**: Dos servidores Nginx que funcionan como intermediarios
- **Capa 3 - Servidor de Aplicación**: Un servidor que ejecuta el código PHP y comparte archivos por NFS
- **Capa 4 - Base de Datos**: Dos bases de datos MariaDB sincronizadas con un HAProxy delante

---

## Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────┐
│                    CLIENTE (localhost:8085)             │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
                ┌───────────────────────┐
                │  Balanceador Nginx    │
                │    192.168.10.2       │
                └───────────┬───────────┘
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
    ┌───────────────┐               ┌───────────────┐
    │   Web1 Nginx  │               │   Web2 Nginx  │
    │ 192.168.10.11 │               │ 192.168.10.12 │
    └───────┬───────┘               └───────┬───────┘
            │                               │
            └───────────────┬───────────────┘
                            ▼
                ┌───────────────────────────┐
                │  ServerNFS (PHP-FPM)      │
                │  192.168.10.10            │
                │  192.168.20.5             │
                └───────────┬───────────────┘
                            │
                            ▼
                ┌───────────────────────┐
                │   HAProxy DB          │
                │   192.168.20.10       │
                └───────────┬───────────┘
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
    ┌───────────────┐               ┌───────────────┐
    │  DB1 (Galera) │               │  DB2 (Galera) │
    │ 192.168.20.20 │               │ 192.168.20.30 │
    └───────────────┘               └───────────────┘
```

### Redes configuradas:

- **Red 1 (192.168.10.0/24)**: Red frontal donde está el balanceador, los servidores web y el servidor de aplicación
- **Red 2 (192.168.20.0/24)**: Red backend donde está el servidor de aplicación, HAProxy y las bases de datos

---

## Explicación del Código

### Vagrantfile

El Vagrantfile define 7 máquinas virtuales que se levantan en un orden específico porque unas dependen de otras:

1. **db1**: Es el primer nodo del cluster de base de datos, arranca el cluster desde cero
2. **db2**: Se une al cluster que ya ha iniciado db1
3. **dbHaproxy**: El balanceador de las bases de datos, necesita que db1 y db2 estén funcionando
4. **serverNfs**: El servidor de aplicación, necesita que HAProxy esté listo para conectarse
5. **web1 y web2**: Los servidores web que redirigen las peticiones al servidor de aplicación
6. **balanceador**: El punto de entrada que reparte tráfico entre web1 y web2

### Scripts de aprovisionamiento

#### `db1_aprov.sh` y `db2_aprov.sh`

Estos scripts configuran un cluster MariaDB Galera, que básicamente hace que dos bases de datos se sincronicen automáticamente entre ellas. La configuración principal está en el archivo `/etc/mysql/mariadb.conf.d/60-galera.cnf` y tiene varios parámetros importantes:

- **wsrep_on**: Activa la replicación síncrona de Galera, lo que significa que cuando guardas algo en una base de datos, se guarda en las dos al mismo tiempo
- **wsrep_cluster_name**: Es el nombre del cluster, todos los nodos del mismo cluster deben tener el mismo nombre
- **wsrep_cluster_address**: Aquí ponemos las IPs de todos los nodos del cluster. Es fundamental porque así los nodos saben dónde buscar a sus compañeros
- **binlog_format = row**: Galera necesita que los cambios se registren fila por fila en lugar de como comandos SQL completos
- **default_storage_engine = InnoDB**: Galera solo funciona con InnoDB, que es el motor de almacenamiento que soporta transacciones
- **innodb_autoinc_lock_mode = 2**: Este modo optimiza cómo se generan los IDs automáticos cuando hay varios servidores escribiendo a la vez
- **wsrep_node_address**: La IP del propio nodo
- **wsrep_provider**: La ruta a la librería de Galera que hace toda la magia de la sincronización
- **bind-address = 0.0.0.0**: Permite que el servidor acepte conexiones desde cualquier red

El script de **db1** ejecuta `galera_new_cluster`, que es un comando especial para iniciar un cluster nuevo. Es como decir "yo soy el primero, los demás que se unan a mí". Después crea la base de datos `users`, importa los datos de la aplicación y crea un usuario llamado `haproxy` sin contraseña. Este usuario es necesario para que HAProxy pueda comprobar si la base de datos está funcionando correctamente.

El script de **db2** simplemente arranca MariaDB normalmente con `systemctl start mariadb`. Como en la configuración ya están las IPs del cluster, db2 automáticamente busca a db1 y se une al cluster.

#### `dbHaproxy_aprov.sh`

HAProxy es el balanceador de las bases de datos. Su trabajo es recibir las conexiones de la aplicación y repartirlas entre db1 y db2. La configuración tiene dos bloques importantes:

**Bloque `listen ClusterGuille`:**

Aquí configuramos cómo HAProxy se comunica con las bases de datos:

- **bind 0.0.0.0:3306**: HAProxy escucha en el puerto 3306, que es el puerto estándar de MySQL. Así la aplicación cree que está hablando con un servidor MySQL normal
- **mode tcp**: Usamos modo TCP en vez de HTTP porque MySQL no habla HTTP, tiene su propio protocolo
- **option tcpka**: Mantiene las conexiones TCP activas. Si hay un problema de red, lo detecta rápido
- **option mysql-check user haproxy**: Este es el health check. HAProxy se conecta a cada base de datos usando el usuario 'haproxy' y hace un ping. Si la base de datos no responde bien, deja de enviarle tráfico
- **balance roundrobin**: El algoritmo de balanceo. Round-robin significa que va rotando: una petición a db1, la siguiente a db2, luego otra vez a db1, y así
- **server nodo1/nodo2**: Define las dos bases de datos con sus IPs y puertos. El parámetro `check` activa los health checks que configuramos arriba

**Bloque `listen stats`:**

Este bloque monta una página web en el puerto 8082 donde puedes ver el estado de todo: qué nodos están funcionando, cuántas conexiones tienen, si hay alguno caído, etc. Está protegido con usuario y contraseña (admin/admin).

Lo importante de HAProxy es que actúa como intermediario transparente. La aplicación PHP solo conoce la IP de HAProxy (192.168.20.10) y para ella es como si fuera un único servidor MySQL. HAProxy se encarga de repartir las peticiones entre db1 y db2 sin que la aplicación se entere.

#### `serverNfs_aprov.sh`

Este servidor hace varias cosas a la vez:

**Como servidor de aplicación PHP:**

Instala PHP-FPM, que es la forma moderna de ejecutar PHP. En vez de arrancar PHP cada vez que llega una petición (que es lento), PHP-FPM mantiene varios procesos PHP corriendo en memoria todo el tiempo, listos para procesar peticiones. Es mucho más rápido.

Nginx se configura para que cuando llegue una petición a un archivo .php, la pase a PHP-FPM a través de un socket Unix (un archivo especial que permite comunicación entre procesos). PHP-FPM procesa el código y devuelve el resultado a Nginx, que se lo envía al cliente.

**Como servidor NFS:**

NFS permite compartir carpetas entre máquinas Linux. En este caso, compartimos `/var/www/crud` con web1 y web2, aunque en realidad en esta arquitectura no es estrictamente necesario porque las webs no acceden directamente a los archivos, solo redirigen las peticiones.

Los parámetros de exportación NFS son:
- `rw`: Lectura y escritura
- `sync`: Las escrituras se hacen de forma síncrona, garantiza que los datos no se pierdan
- `no_subtree_check`: Mejora el rendimiento desactivando ciertas comprobaciones

**Configuración de la aplicación:**

Crea el archivo `config.php` que tiene las credenciales para conectarse a la base de datos. Lo importante aquí es que la IP que ponemos es la de HAProxy (192.168.20.10), no las IPs de las bases de datos directamente. Así la aplicación no sabe que hay dos bases de datos, solo conoce HAProxy y él se encarga de todo.

#### `web_aprov.sh`

Este script configura Nginx para que funcione solo como proxy inverso. No sirve archivos ni ejecuta PHP, solo reenvía peticiones. Cuando llega una petición, Nginx la redirige tal cual al servidor de aplicación (192.168.10.10).

Los headers que configuramos son importantes:
- `proxy_set_header Host $host`: Mantiene el nombre de host original
- `proxy_set_header X-Real-IP $remote_addr`: Guarda la IP real del cliente que hizo la petición
- `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for`: Va añadiendo las IPs de todos los proxies por los que pasa la petición

Estos headers son necesarios porque si no los ponemos, el servidor de aplicación vería como origen la IP del servidor web en vez de la IP del cliente real.

#### `balanceador_aprov.sh`

Este es el punto de entrada de toda la infraestructura. Define un grupo de servidores backend (web1 y web2) en el bloque `upstream` y usa round-robin para repartir las peticiones entre ellos.

Nginx es bastante listo: mantiene conexiones persistentes con los backends para que no tenga que abrir y cerrar conexiones todo el tiempo, y si detecta que un servidor no responde, automáticamente deja de enviarle tráfico hasta que vuelva a estar disponible.

---

## Problemas Comunes

### 1. Cluster Galera no sincroniza
**Síntoma:** Al comprobar el tamaño del cluster solo aparece 1 nodo en vez de 2

**Solución:**

A veces db2 arranca muy rápido y no encuentra a db1 todavía listo. Simplemente reiniciamos db2:

```bash
vagrant ssh db2
sudo systemctl restart mariadb
sudo mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
exit
```

### 2. HAProxy marca nodos en rojo
**Síntoma:** En el panel web de HAProxy los nodos aparecen caídos

**Solución:**

Probablemente falta el usuario haproxy que se usa para los health checks:

```bash
vagrant ssh db1
sudo mysql -e "CREATE USER IF NOT EXISTS 'haproxy'@'%'; FLUSH PRIVILEGES;"
exit
```

### 3. Error de conexión a base de datos
**Síntoma:** La aplicación web muestra "Could not connect to database"

**Solución:**

HAProxy puede que tardara en levantarse. Reiniciamos los servicios en el servidor de aplicación:

```bash
vagrant ssh serverNfs
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm
exit
```

### 4. Nginx devuelve 502 Bad Gateway
**Síntoma:** Los servidores web no pueden conectar con el servidor de aplicación

**Solución:**

Hay que verificar que el servidor de aplicación tenga Nginx funcionando:

```bash
vagrant ssh serverNfs
sudo systemctl status nginx
```

También se puede comprobar si hay conectividad haciendo ping desde web1 o web2:

```bash
vagrant ssh web1
ping 192.168.10.10
```

### 5. Versión de PHP incorrecta
**Síntoma:** Error diciendo que no existe php8.2-fpm.sock

**Solución:**

Debian puede que tenga instalada otra versión de PHP. Comprobamos cuál es:

```bash
vagrant ssh serverNfs
php -v
```

Y ajustamos en `/etc/nginx/sites-available/phpserver` el socket correcto según la versión instalada.

---

## Pruebas de Funcionamiento

[Video demostrativo del despliegue y las pruebas](./pruebas/screencash.mp4)

---

## Despliegue

### Requisitos previos
- VirtualBox 7.0 o superior
- Vagrant 2.3 o superior
- Al menos 4 GB de RAM disponible

### Instalación

1. Verificar que todos los scripts de aprovisionamiento estén en la misma carpeta que el Vagrantfile:
```bash
ls -1
# Debe mostrar:
# Vagrantfile
# balanceador_aprov.sh
# db1_aprov.sh
# db2_aprov.sh
# dbHaproxy_aprov.sh
# serverNfs_aprov.sh
# web_aprov.sh
```

2. Levantar toda la infraestructura:
```bash
vagrant up
```

3. Verificar el estado:
```bash
vagrant status
```

### Acceso a la aplicación

Una vez desplegado, acceder a:
- Aplicación CRUD: `http://localhost:8085`
- Panel HAProxy: `http://192.168.20.10:8082` (admin/admin)

---

## Referencias

- [Nginx HTTP Load Balancer](https://docs.nginx.com/nginx/admin-guide/load-balancer/http-load-balancer/)
- [Galera MariaDB - José Domingo Muñoz](https://www.josedomingo.org/pledin/2022/02/galera-mariadb/)
- [HAProxy Documentation](https://www.haproxy.org/#docs)