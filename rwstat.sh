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
filtro_comm=""
filtro_dataMin=""
filtro_dataMax=""
filtro_user=""
filtro_pidMin=""
filtro_pidMax=""
filtro_linhasMax=""


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
    echo "DEBUG: filtro_dataMin = $filtro_dataMin; filtro_dataMax = $filtro_dataMax"

    # Declarar todas estas variáveis como dicionários («arrays associativos»).
    declare -A all_comms
    declare -A all_users
    declare -A all_prev_bytesRead
    declare -A all_prev_bytesWritten
    declare -A all_curr_bytesRead
    declare -A all_curr_bytesWritten
    declare -A all_readRates
    declare -A all_writeRates
    declare -A all_dates

    for pid in $allWorkingPids
    {
        comm=$(cat /proc/"$pid"/comm 2>/dev/null)
        user=$(ls -ld /proc/"$pid" 2>/dev/null | awk '{print $3}')
        prev_bytesRead=$(cat /proc/"$pid"/io 2>/dev/null | grep -o '^rc.*' | cut -d " " -f 2)
        prev_bytesWritten=$(cat /proc/"$pid"/io 2>/dev/null | grep -o '^wc.*' | cut -d " " -f 2)
        date=$(LANG=C ls -ld /proc/"$pid" 2>/dev/null | awk '{print $6, $7, $8}')
        unix_date=$(calcular_data "$date")

        # Filtrar
        if [[ (-n $filtro_dataMin && $unix_date -le $filtro_dataMin) ||
              (-n $filtro_dataMax && $unix_date -ge $filtro_dataMax) ]]; then
            echo "DEBUG: PID $pid foi filtrado (tinha a data: $date ($unix_date))"
            continue;
        fi

        sleep "$numeroSegundos"

        curr_bytesRead=$(cat /proc/"$pid"/io  2>/dev/null | grep -o '^rc.*' | cut -d " " -f 2)
        curr_bytesWritten=$(cat /proc/"$pid"/io  2>/dev/null | grep -o '^wc.*' | cut -d " " -f 2)

        differenceReadBytes=$((curr_bytesRead-prev_bytesRead))
        readRates=$(echo "scale=2 ; $differenceReadBytes / $numeroSegundos" | bc )

        differenceWriteBytes=$((curr_bytesWritten-prev_bytesWritten))
        writeRates=$(echo "scale=2 ; $differenceWriteBytes / $numeroSegundos" | bc)

        all_comms[$pid]=$comm
        all_users[$pid]=$user
        all_prev_bytesRead[$pid]=$prev_bytesRead
        all_prev_bytesWritten[$pid]=$prev_bytesWritten
        all_curr_bytesRead[$pid]=$curr_bytesRead
        all_curr_bytesWritten[$pid]=$curr_bytesWritten
        all_readRates[$pid]=$readRates
        all_writeRates[$pid]=$writeRates
        all_dates[$pid]=$date
    }

    for pid in $allWorkingPids
    {
        comm=${all_comms[$pid]}
        user=${all_users[$pid]}
        readBytesBefore=${all_prev_bytesRead[$pid]}
        writeBytesBefore=${all_prev_bytesWritten[$pid]}
        myDate=${all_dates[$pid]}
        rateR=${all_readRates[$pid]}
        rateW=${all_writeRates[$pid]}

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
        echo "DEBUG: OPTARG = $OPTARG;   target = $target;  arg = $arg; optstring = ${optstring}"

        case $arg in
            c )
                filtro_comm=$target
                ;;
            s )
                data=$(calcular_data "$target")
                filtro_dataMin=$data
                ;;
            e )
                data=$(calcular_data "$target")
                filtro_dataMax=$data
                ;;
            u )
                filtro_user=$target
                ;;
            m )
                filtro_pidMin=$target
                ;;
            M )
                filtro_pidMax=$target
                ;;
            p )
                filtro_linhasMax=$target
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

function filtrar_linhas()
{
    if [[ -n $filtro_comm ]]; then
        echo "DEBUG: A filtrar por comm."
        awk -F"|" -e '{ if($1 ~ '"/^$filtro_comm/"') {print}}' $tempfile > tmpfile && mv tmpfile $tempfile
    fi

    if [[ -n $filtro_user ]]; then
        echo "DEBUG: A filtrar por user ($filtro_user)."
        awk -F"|" -e '{ if($2 ~ '"/$filtro_user/"') {print}}' $tempfile > tmpfile && mv tmpfile $tempfile
    fi

    if [[ -n $filtro_pidMin ]]; then
        echo "DEBUG: A filtrar por PID mínimo."
        awk -F"|" '{ if($3 >= '"$filtro_pidMin"') {print}}' $tempfile > tmpfile && mv tmpfile $tempfile
    fi

    if [[ -n $filtro_pidMax ]]; then
        echo "DEBUG: A filtrar por PID máximo."
        awk -F"|" '{ if($3 <= '"$filtro_pidMax"') {print}}' $tempfile > tmpfile && mv tmpfile $tempfile
    fi
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

function cortar_linhas()
{
    if [[ -n $filtro_linhasMax ]]; then
            echo "DEBUG: A filtrar por quantidade de linhas."
            head -n "$filtro_linhasMax" $tempfile > tmpfile && mv tmpfile $tempfile
    fi
}

function imprimir_tabela()
{
    filtrar_linhas
    ordenar_linhas
    cortar_linhas
    column $tempfile -t -s $'|' -N "COMM,USER,PID,READB,WRITEB,RATER,RATEW,DATE" -R 3,4,5,6,7,8
    rm $tempfile
}

verificar_argumentos "$@"
argumentos "$@"
calcular_valores
imprimir_tabela
