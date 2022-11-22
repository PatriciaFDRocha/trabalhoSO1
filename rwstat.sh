#!/bin/bash
#!/usr/bin/env bash
#This script gets the statistics of reading/writing on running processes

# argumento for the number of seconds
# vai ser sempre o último argumento
numeroSegundos=${!#}

optstring=":c:s:e:u:m:M:p:rw"
regexNumber='^[0-9]+$'

function argumentos()
{
    ## verifica que 1 argumento é passado
    [[ $# -eq 0 ]] && echo "No arguments passed" >&2; exit 1;

    ## verifica que o número passado é válido
    [[ $numeroSegundos =~ $regexNumber ]] || [[ $numeroSegundos -le 0 ]] || echo "Must be a number" >&2; exit 1;

    # # número de segundos precisa de ser superior a zero para calcular i/o
    # [[ $numeroSegundos -le 0 ]] && echo "Invalid number" >&2;
}

function processa_erro()
{
    echo "Erro" 1>&2;
}

function calcular_data()
{
	date -d "$target" +"%s"
}


function calcular_argumentos()
{
    while getopts ${optstring} arg; do

        target=$OPTARG

        case ${arg} in
            c )
                comm=$(cat /proc/$$/comm | grep "$target" ) || processa_erro #funciona
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
                user=$(ls -ls /proc/$$/io | grep "$target") || processa_erro #funciona

                if [ -z "${user}" ];
                    then 
                        processa_erro      
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
                if [[ $$ =~ ^${target:0:2}.*$ ]]; # funciona se target tiver 2 ou mais caracteres
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

function calcular_valores()
{
    allWorkingPids=$(ls -l /proc | awk '{print $9}' | grep -o '^[0-9]*')
    
    for p in $allWorkingPids
    {
        pid=$p || processa_erro
    
        comm=$(cat /proc/$pid/comm) || processa_erro # OUTPUT: bash

        user=$(ls -ld /proc/$pid | awk '{print $3}') || processa_erro # OUTPUT: root

        # ls -l /proc | awk '{print $9}' | grep -o '^[0-9]*' - pids

        readBytesBefore=$(find /proc/ | cat /proc/$pid/io | grep -o '^rc.*' | cut -d " " -f 2) || processa_erro  # OUTPUT: read_bytes: 38294

        writeBytesBefore=$(find /proc/ | cat /proc/$pid/io | grep -o '^wc.*' | cut -d " " -f 2) || processa_erro  # OUTPUT: write_bytes: 192

        sleep "$numeroSegundos"

        readBytesAfter=$(find /proc/ | cat /proc/$pid/io | grep -o '^rc.*' | cut -d " " -f 2) || processa_erro

        writeBytesAfter=$(find /proc/ | cat /proc/$pid/io | grep -o '^wc.*' | cut -d " " -f 2) || processa_erro

        rateR=$((readBytesAfter - readBytesBefore)) #|| processa_erro # OUTPUT: rateR: 66270,00

        rateW=$((writeBytesAfter - writeBytesBefore)) || processa_erro # OUTPUT: rateW: 234,00

        myDate=$(ls -ld . | awk '{print $6, $7, $8}') || processa_erro
    
        imprimir_tabela
    }
}
    

function imprimir_tabela()
{
    (
		printf 'COMM\tUSER\tPID\tREADB\tWRITEB\tRATER\tRATEW\tDATE\n'
    	printf '%s\t%s\t%s\t%s\t%s\t%.2f\t%.2f\t%s\n' \
		"$comm" "$user" "$pid" "$readBytesBefore" "$writeBytesBefore" "$rateR" "$rateW" "$myDate" \
	) | column -t -s $'\t' # output values
}

# argumentos "$@"
calcular_argumentos "$@"
calcular_valores
imprimir_tabela