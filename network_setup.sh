#!/bin/bash

# функция логирования
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

# предупреждение пользователей
echo "внимание: выполнение этого скрипта может повлиять на ваше сетевое подключение"
echo "убедитесь, что вы осознаете свои действия и имеете резервное подключение к сети, если это необходимо"
read -p "Продолжить? (y/n): " choice
if [[ "$choice" != "y" ]]; then
    exit 1
fi

# проверка прав доступа
if [[ $EUID -ne 0 ]]; then
    echo "этот скрипт должен быть выполнен с правами суперпользователя" >&2
    exit 1
fi

# проверка наличия IP-адреса
if [[ -z "$1" ]]; then
    echo "пожалуйста, укажите новый ip-адрес" >&2
    exit 1
fi

NEW_IP=$1

# определение операционной системы
OS=""
if [ -f /etc/debian_version ]; then
    OS="debian"
    INTERFACES_FILE="/etc/network/interfaces"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
    INTERFACES_FILE="/etc/sysconfig/network-scripts/ifcfg-$(ip route show default | awk '/default/ {print $5}')"
else
    echo "неподдерживаемая операционная система" >&2
    exit 1
fi

# установка путей к файлам резервной копии и логов
BACKUP_FILE="${INTERFACES_FILE}.bak"
LOG_FILE="/var/log/network_setup.log"

# создание файла конфигурации сети, если его нет
if [ ! -f "$INTERFACES_FILE" ]; then
    log "файл конфигурации сети не найден. создание нового файла"
    if [ "$OS" = "debian" ]; then
        #cat <<EOL > $INTERFACES_FILE
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $NEW_IP
    netmask 255.255.255.0
    gateway 192.168.1.1
EOL
    elif [ "$OS" = "redhat" ]; then
        INTERFACE_NAME=$(basename $INTERFACES_FILE | sed 's/^ifcfg-//')
        cat << EOL > $INTERFACES_FILE
DEVICE=$INTERFACE_NAME
BOOTPROTO=none
ONBOOT=yes
IPADDR=$NEW_IP
NETMASK=255.255.255.0
GATEWAY=192.168.1.1
EOL 
    fi
else
    # создание резервной копии файла конфигурации сети
    log "создание резервной копии файла конфигурации сети"
    cp $INTERFACES_FILE $BACKUP_FILE || { echo "Ошибка при создании резервной копии" >&2; log "Ошибка при создании резервной копии"; exit 1; }

    # замена ip-адреса в файле конфигурации сети в зависимости от os
    log "замена ip-адреса в файле конфигурации сети"
    if [ "$OS" = "debian" ]; then
        sed -i "s/^\(address\s\).*/\1$NEW_IP/" $INTERFACES_FILE || { echo "Ошибка при изменении IP-адреса" >&2; log "Ошибка при изменении IP-адреса"; exit 1; }
    elif [ "$OS" = "redhat" ]; then
        sed -i "s/^IPADDR=.*/IPADDR=$NEW_IP/" $INTERFACES_FILE || { echo "Ошибка при изменении IP-адреса" >&2; log "Ошибка при изменении IP-адреса"; exit 1; }
    fi
fi

# получение текущей сетевой конфигурации
log "получение текущей сетевой конфигурации"
NETWORK_INFO=$(ip addr show)

# форматирование и вывод сетевой конфигурации
FORMATTED_NETWORK_INFO=$(echo "$NETWORK_INFO" | grep -E "inet |link/ether" | awk '{print "Интерфейс: " $NF, "\nIP-адрес: " $2, "\nMAC-адрес: " $4, "\n"}')

# вывод информации
echo -e " текущая сетевая конфигурация:\n$FORMATTED_NETWORK_INFO"

# сообщение об успешном завершении задачи
echo "конфигурация сети была успешно изменена на $NEW_IP"

log "конфигурация сети была успешно изменена на $NEW_IP"

# изменения mac-адреса
change_mac_address() {
    local INTERFACE=$1
    local NEW_MAC=$2

    log "изменение mac-адреса для интерфейса $INTER"
    ip link set dev $INTERFACE down || { echo "Ошибка при изменении mac-адреса" >&2; log "Ошибка при изменении mac-адреса"; exit 1; }
    ip link set dev $INTERFACE address $NEW_MAC || { echo "Ошибка при изменении mac-адреса" >&2; log "Ошибка при изменении mac-адреса"; exit 1; }
    ip link set dev $INTERFACE up || { echo "Ошибка при изменении mac-адреса" >&2; log "Ошибка при изменении mac-адреса"; exit 1; }
}


echo "задача выполнена успешно"
log "скрипт завершен успешно"

# пример использования функции change_mac_address и изменение ip
# sudo ./network_setup.sh change_mac_address eth0 00:11:22:33:44:55
# sudo ./network_setup.sh 192.168.1.100
