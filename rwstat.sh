#!/bin/bash
#!/usr/bin/env bash
#This script gets the statistics of reading/writing on running processes

# argumento for the number of seconds
# vai ser sempre o último argumento
numeroSegundos=${!#}

optstring=":c:s:e:u:m:M:p:rw"
regexNumber='^[0-9]+$'

# Criar um ficheiro temporário.
tempfile=$(mktemp) || tempfile="rwstat-$$.temp"

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
    echo "Error: $1"
    exit 1
}

function error_handling()
{
    [ ! -d "$1" ] >/dev/null 2>&1
    [ ! -f "$1" ] >/dev/null 2>&1
}

function calcular_valores()
{
    printf 'COMM|USER|PID|READB|WRITEB|RATER|RATEW|DATE\n' >> $tempfile

    allWorkingPids=$(ps -e | awk '{print $1 }' | grep -E '[0-9]')
    # allWorkingPids=$(ls -l /proc | awk '{print $9}' | grep -o '^[0-9]*') || error_handling "$allWorkingPids"

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
        comms[$pid]=$(cat /proc/"$pid"/comm) || error_handling "${comms[$pid]}" # OUTPUT: bash
        users[$pid]=$(ls -ld /proc/"$pid" | awk '{print $3}') || error_handling "${users[$pid]}" # OUTPUT: root
        prev_bytesRead[$pid]=$(< /proc/"$pid"/io grep -o '^rc.*' | cut -d " " -f 2) || error_handling "${prev_bytesRead[$pid]}"  # OUTPUT: read_bytes: 38294
        prev_bytesWritten[$pid]=$(< /proc/"$pid"/io grep -o '^wc.*' | cut -d " " -f 2) || error_handling "${prev_bytesWritten[$pid]}"  # OUTPUT: write_bytes: 192
        dates[$pid]=$(LANG=C ls -ld /proc/"$pid" | awk '{print $6, $7, $8}') || error_handling "${dates[$pid]}"
    }

    sleep "$numeroSegundos"

    for pid in $allWorkingPids
    {
        curr_bytesRead[$pid]=$(< /proc/"$pid"/io grep -o '^rc.*' | cut -d " " -f 2) || error_handling "$curr_bytesRead"
        curr_bytesWritten[$pid]=$(< /proc/"$pid"/io grep -o '^wc.*' | cut -d " " -f 2) || error_handling "$curr_bytesWritten"

        differenceReadBytes=$((curr_bytesRead[$pid]-prev_bytesRead[$pid]))
        readRates[$pid]=$(echo "scale=2 ; $differenceReadBytes / $numeroSegundos" | bc ) || error_handling "${readRates[$pid]}" # OUTPUT: rateR: 66270,00

        differenceWriteBytes=$((curr_bytesWritten[$pid]-prev_bytesWritten[$pid]))
        writeRates[$pid]=$(echo "scale=2 ; $differenceWriteBytes / $numeroSegundos" | bc) || error_handling "${writeRates[$pid]}" # OUTPUT: rateW: 234,00
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
        echo "${result[0]}|${result[1]}|${result[2]}|${result[3]}|${result[4]}|${result[5]}|${result[6]}|${result[7]}" >> $tempfile
    }
}


function calcular_data()
{
	date -d "$target" +"%s"
}

function argumentos()
{
    while getopts ${optstring} arg; do

        target=$OPTARG

        case ${arg} in
            c )
                comm=$(cat /proc/$$/comm | grep "$target" ) #funciona
                ;;
            s )
                echo "Opção opcaoMinDate escolhida"
                data=$(calcular_data target)

                $result | grep "$data" # ainda não funciona
                ;;
            e )
                echo "Opção opcaoMaxDate escolhida"
                data=$(calcular_data target)

                $result | grep "$data" # ainda não funciona
                ;;
            u )
                user=$(ls -ls /proc/$$/io | grep "$target") #funciona

                if [ -z "${user}" ];
                    then
                        processa_erro "$1"
                    else
                        $user | awk '{print $4}'
                fi
                ;;
            m )
                echo "Opção opcaoMinPID escolhida" # imprime apenas os pids que fazem match aquele target # funciona
                if [[ $$ =~ ^${target:0:1}.*$ ]]; # funciona se target tiver 2 ou mais caracteres
                    # if [ -z "${pid}" ];
                    #     then
                    #         processa_erro
                    # fi
                    then
                        pid=$$
                    else
                        processa_erro
                fi
                ;;
            M )
                echo "Opção opcaoMaxPID escolhida" #ainda não funciona
                if [[ $$ =~ ^${target:0:1}.*$ ]]; # funciona se target tiver 2 ou mais caracteres
                    # if [ -z "${pid}" ];
                    #     then
                    #         processa_erro
                    # fi
                    then
                        pid=$$
                    else
                        processa_erro
                fi
                ;;
            p )
                echo "Opção opcaoNumProcesses escolhida"
                $result | head -n "$target" # ainda não funciona
                ;;
            r )
                echo "Opção opcaoSortReverse escolhida"
                sort -r # ainda não funciona
                ;;
            w )
                echo "Opção opcaoSortWrite escolhida"
                sort k5 # ainda não funciona
                ;;
            ? )
                echo "Opção inválida"
                ;;
        esac

    done
}


function imprimir_tabela()
{
    column $tempfile -t -s $'|' -R 3,4,5,6,7,8
    rm $tempfile
}

verificar_argumentos "$@"
calcular_valores
argumentos "$@"
imprimir_tabela
