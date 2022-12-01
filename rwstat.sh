#!/bin/bash
#!/usr/bin/env bash
#This script gets the statistics of reading/writing on running processes

###############################
# Variáveis globais   #########
###############################

# argumento for the number of seconds
# vai ser sempre o último argumento
numeroSegundos=${!#}

optstring=":c:s:e:u:m:M:p:rw"
regexNumber='^[0-9]+$'

# Criar um ficheiro temporário.
tempfile=$(mktemp) || tempfile="rwstat-$$.temp"

# Parâmetros de filtragem e ordenação
ord_coluna=""       # Ordenar por esta coluna no final
ord_inverter="0"    # Inverter a ordem ou não.
filtro_dataMin=""
filtro_dataMax=""


function verificar_argumentos()
{
    ## verifica que pelo menos 1 argumento é passado
    [[ $# -eq 0 ]] && processa_erro $#

    ## verifica que o número passado é válido
    [[ $numeroSegundos =~ $regexNumber ]] || processa_erro $numeroSegundos

    # número de segundos precisa de ser superior a zero para calcular i/o
    [[ $numeroSegundos -gt 0 ]] || processa_erro $numeroSegundos
}

function processa_erro()
{
    echo "Invalid Argument: $1"
    exit 1
}

function calcular_valores()
{
    allWorkingPids=$(ps | awk '{print $1 }' | grep -E '[0-9]')

    # Declarar todas estas variáveis como dicionários («arrays associativos»).
    declare -A comms
    declare -A users
    declare -A prev_bytesRead
    declare -A prev_bytesWritten
    declare -A curr_bytesRead
    declare -A curr_bytesWritten
    declare -A readRates
    declare -A writeRates
    declare -A dates

    for pid in $allWorkingPids
    {
        comms[$pid]=$(cat /proc/"$pid"/comm 2>/dev/null)
        users[$pid]=$(ls -ld /proc/"$pid" 2>/dev/null | awk '{print $3}')
        prev_bytesRead[$pid]=$(cat /proc/"$pid"/io 2>/dev/null | grep -o '^rc.*' | cut -d " " -f 2)
        prev_bytesWritten[$pid]=$(cat /proc/"$pid"/io 2>/dev/null | grep -o '^wc.*' | cut -d " " -f 2)
        dates[$pid]=$(LANG=C ls -ld /proc/"$pid" 2>/dev/null | awk '{print $6, $7, $8}')

        sleep "$numeroSegundos"

        curr_bytesRead[$pid]=$(cat /proc/"$pid"/io  2>/dev/null | grep -o '^rc.*' | cut -d " " -f 2)
        curr_bytesWritten[$pid]=$(cat /proc/"$pid"/io  2>/dev/null | grep -o '^wc.*' | cut -d " " -f 2)

        differenceReadBytes=$((curr_bytesRead[$pid]-prev_bytesRead[$pid]))
        readRates[$pid]=$(echo "scale=2 ; $differenceReadBytes / $numeroSegundos" | bc )

        differenceWriteBytes=$((curr_bytesWritten[$pid]-prev_bytesWritten[$pid]))
        writeRates[$pid]=$(echo "scale=2 ; $differenceWriteBytes / $numeroSegundos" | bc)
    }

    for pid in $allWorkingPids
    {
        comm=${comms[$pid]}
        user=${users[$pid]}
        readBytesBefore=${prev_bytesRead[$pid]}
        writeBytesBefore=${prev_bytesWritten[$pid]}
        myDate=${dates[$pid]}
        rateR=${readRates[$pid]}
        rateW=${writeRates[$pid]}

        result=("$comm" "$user" "$pid" "$readBytesBefore" "$writeBytesBefore" "$rateR" "$rateW" "$myDate")

        if [ -z "$comm" ]; then
            continue
        else
            echo "${result[0]}|${result[1]}|${result[2]}|${result[3]}|${result[4]}|${result[5]}|${result[6]}|${result[7]}" >> $tempfile
        fi
    }
}


function calcular_data()
{
    date -d "$1" +"%s"
}

function argumentos()
{
    while getopts ${optstring} arg; do

        target=$OPTARG

        case ${arg} in
            c )
                awk -F"|" -e '{ if($1 ~ '"/^$target/"') {print}}' $tempfile > tmpfile && mv tmpfile $tempfile
                ;;
            s )
                data=$(calcular_data "$target")
                filtro_dataMin=$data
                awk -F'|' '{ if('"calcular_data $8"' >= '"$data"') { print }}'
                ;;
            e )
                echo "Opção opcaoMaxDate escolhida"
                data=$(calcular_data "$target")
                filtro_dataMax=$data
                ;;
            u )
                awk -F"|" -e '{ if($2 ~ '"/$target/"') {print}}' $tempfile > tmpfile && mv tmpfile $tempfile
                ;;
            m )
                awk -F"|" '{ if($3 >= '"$target"') {print}}' $tempfile > tmpfile && mv tmpfile $tempfile
                ;;
            M )
                awk -F"|" '{ if($3 <= '"$target"') {print}}' $tempfile > tmpfile && mv tmpfile $tempfile
                ;;
            p )
                head -n "$target" $tempfile > tmpfile && mv tmpfile $tempfile
                ;;
            r )
                ord_inverter="1"
                ;;
            w )
                ord_coluna="7"
                ;;
            ? )
                echo "Invalid option"
                exit 1;
                ;;
        esac

    done
}

function ordenar_linhas()
{
    if [[ -n $ord_coluna ]]; then
        declare -a sort_options=("-k $ord_coluna,$ord_coluna")

        if [[ $ord_inverter -eq 0 ]]; then
            sort_options+=("-r")
        fi

        sort $tempfile "${sort_options[@]}" -g -t '|' -o $tempfile
    fi
}

function imprimir_tabela()
{
    ordenar_linhas
    column $tempfile -t -s $'|' -N "COMM,USER,PID,READB,WRITEB,RATER,RATEW,DATE" -R 3,4,5,6,7,8
    rm $tempfile
}

verificar_argumentos "$@"
calcular_valores
argumentos "$@"
imprimir_tabela
