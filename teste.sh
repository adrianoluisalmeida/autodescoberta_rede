#!/bin/bash
#-- Autor: Adriano Almeida (alalmeida@inf.ufsm.br)
#-- Data......: 21/09/2019




# Conexoes
    echo -e "Buscando as conexões ativas"
    qtConexoes=`sudo ifconfig -a | grep broadcast -c`  

    if [ "$qtConexoes" -eq 0 ]; then
        echo -e "\n  Nenhuma conexão ativa. \n"
        exit        
    else
        if [ "$qtConexoes" -eq 1 ]; then
            echo -e "   Uma conexão ativa."
        else
            echo -e "   $qtConexoes conexões ativas."        
        fi
    fi

# Interfaces
    echo -e " > Obtendo Nomes da(s) interface(s) de rede..."
    interfaces=( `sudo ifconfig -a | grep broadcast -B 1 | cut -d ":" -f1 -s | sed 's/ //g'` )  

# Inets
    echo -e " > Obtendo IP(s) da(s) interface(s) de rede..."
    inets=( `sudo ifconfig -a | grep broadcast | cut -d "n" -f2 | sed 's/et//g' | sed 's/ //g'` )

# Selecao das interfaces
    selecionada=0     
    i=0
    n=0
    if [ "$qtConexoes" != "1" ]; then
        echo -e "\n As seguintes interfaces de rede estão conectadas:"
        echo -e "  ----------------------------------"
        for inet in ${inets[@]}
        do
            let n=$n+1
            opcoes=( ${opcoes[@]} "$n" )
            echo -e "     $n-${interfaces[$i]}\t IP:$inet"
            let i=$i+1
        done    
        echo -e "  ----------------------------------"
        
        invalida=1
        texto="   Selecione uma interface delas: "
        while [ $invalida -eq 1 ]; do
            echo -e -n "$texto"
            read selecionada
            texto="   Digite o NÚMERO que deseja selecionar: "
            for opc in ${opcoes[@]}
            do
                if [ "$selecionada" = "$opc" ]; then
                    invalida=0
                fi
            done
        done        

        let selecionada=$selecionada-1
    fi
    interface=${interfaces[$selecionada]}
    inet=${inets[$selecionada]}


# Gateway Padrão
    lin=( `sudo netstat -r -n | grep -m1 "$interface"` )
    gateway=${lin[1]}
    echo -e -n "\n > Gateway Padrão da interface [$interface] = $gateway"

# Prefixo
    octetos=( ${gateway//'.'/' '} )
    prefixo="${octetos[0]}.${octetos[1]}.${octetos[2]}"
    echo -e "\n > Prefixo da rede = $prefixo"
# IPs conectados
    echo -e -n " > Pesquisando IPs conectados à rede..."
    ips=( `sudo nmap -sP -n -T5 --exclude "$gateway" "$prefixo.0-255" | grep "Nmap scan report for " | cut -d " " -f5` )

echo -e -n "\n > Ob dispositivos conectados à rede..."    
echo -e "\n "
         
echo -e " IP\t\t->\tDispositivo"
echo -e " -------------------------------------------------------------------"
i=0


sqlite3 ./descoberta.dba <<EOS
        insert into descoberta (date) 
                   values(datetime('now','localtime'));
    
EOS
id=$(sqlite3 ./descoberta.dba "select id from descoberta order by id desc limit 1")

arrayLastIps=("")
arrayLast=("")

countI=0
for ip in ${ips[@]}
do
    echo -n -e " ${ips[$i]}\t->\t"
    nome="nenhum"

    for inet in ${inets[@]}
    do
        # Se o ip pesquisado for do próprio computador que está realizando a consulta
        if [ $ip = $inet ]; then
            nome=`uname -n`                
        fi 
    done

    if [ "$nome" = "nenhum" ]; then
        # Nome do Fabricante da placa de rede       
        nome=`sudo nmap -sP -n $ip | grep "MAC Address: "`
    fi

    countRegisters=$(sqlite3 ./descoberta.dba "select count(*) from ips where mac like '%$nome%'")

    lastIp=$(sqlite3 ./descoberta.dba "insert into ips (ip, mac, descoberta_id) 
            values('$ip', '$nome', '$id')")

    if [ "$countRegisters" == 0 ]; then
        arrayLastIps[$countI]=${ip}
        ##arrayLast[$countI]=" ${ip}\t->\t"$nome
        let countI=$i+1
    fi

    echo -e $nome
    let i=$i+1
done


echo -e " -------------------------------------------------------------------" 

echo -e " IP\t\t->\tNovos Dispositivos"
echo -e " -------------------------------------------------------------------"

i=0
for ar in ${arrayLastIps[@]}
do

    echo -n -e " ${ar}\t->\t"
    nome="nenhum"

    
    for inet in ${inets[@]}
    do
        # Se o ip pesquisado for do próprio computador que está realizando a consulta
        if [ $ar = $inet ]; then
            nome=`uname -n`                
        fi 
    done

    if [ "$nome" = "nenhum" ]; then
        # Nome do Fabricante da placa de rede       
        nome=`sudo nmap -sP -n $ar | grep "MAC Address: "`
    fi

    echo -e $nome

    #echo -n -e " ${arrayLastIps[$i]}"
    let i=$i+1
done
