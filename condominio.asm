# ==========================================================
# Equipe: Alisson Xavier e Joao Lucas Ribeiro
# Atividade: Projeto 01 - 1a VA
# Disciplina: Arquitetura e Organizacao de Computadores
# Semestre: 2026.2
# Descricao: shell MIPS para cadastro de moradores e automoveis,
# consultas, limpeza dos apartamentos e persistencia em arquivo.
# ==========================================================
# CONSTANTES DO PROJETO
# ==========================================================

.eqv NUM_APS        24       # 12 andares x 2 apartamentos por andar
.eqv AP_SIZE        300      # tamanho, em bytes, reservado para cada AP
.eqv TOTAL_BYTES    7200     # 24 x 300 bytes
.eqv MAX_MORADORES  6        # limite de moradores em cada AP
.eqv NOME_SIZE      32       # espaco fixo de cada nome, incluindo o zero final
.eqv OFF_NOMES      4        # nomes comecam 4 bytes depois do inicio do AP
.eqv OFF_TIPO       196      # campo usado pelos automoveis
.eqv AUTOS_BYTES    104      # 4 bytes de tipo + 4 de quantidade + 96 de slots
.eqv OFF_QTD        200      # quantidade de automoveis
.eqv OFF_AUTO0      204      # primeiro slot de automovel
.eqv OFF_PLACA0     236      # placa do primeiro slot
.eqv OFF_AUTO1      252      # segundo slot de automovel
.eqv OFF_PLACA1     284      # placa do segundo slot
.eqv AUTO_SIZE      48       # bytes reservados por automovel
.eqv AUTO_PLACA     32       # deslocamento da placa dentro do slot
.eqv PLACA_SIZE     16       # tamanho maximo da placa, incluindo zero


# ==========================================================
# DADOS DO PROGRAMA
# ==========================================================

.data

# Banner mostrado antes de cada entrada.
# AJ corresponde as iniciais conhecidas de Alisson e Joao.
banner:          .asciiz "AJ-shell>> "

# Mensagens utilizadas pelas rotinas deste arquivo.
msg_invalido:    .asciiz "Comando invalido\n"
msg_ap_inval:    .asciiz "Falha: AP invalido\n"
msg_max_morad:   .asciiz "Falha: AP com numero max de moradores\n"
msg_morad_nao:   .asciiz "Falha: morador nao encontrado\n"
msg_nome_inv:    .asciiz "Falha: nome invalido\n"
txt_all:         .asciiz "all"
txt_c:           .asciiz "c"
txt_m:           .asciiz "m"
txt_ap:          .asciiz "AP: "
txt_vazio:       .asciiz "Apartamento vazio\n"
txt_morad:       .asciiz "Moradores:\n"
txt_carro:       .asciiz "Carro:\n"
txt_moto:        .asciiz "Moto:\n"
txt_sep:         .asciiz " / "
txt_nl:          .asciiz "\n"
txt_nvazios:     .asciiz "Nao vazios: "
txt_vazios:      .asciiz "Vazios: "
txt_pa:          .asciiz " ("
txt_pf:          .asciiz "%)\n"
msg_max_auto:    .asciiz "Falha: AP com numero max de automoveis\n"
msg_tipo_inv:    .asciiz "Falha: tipo invalido\n"
msg_auto_nao:    .asciiz "Falha: automovel nao encontrado\n"
msg_modelo_inv:  .asciiz "Falha: modelo invalido\n"
msg_placa_inv:   .asciiz "Falha: placa invalida\n"
msg_arq_erro:    .asciiz "Falha: nao foi possivel acessar o arquivo\n"
# Caminho absoluto para o arquivo criado junto ao codigo deste projeto.
arq_nome:        .asciiz "C:/Users/aliss/condominio/condominio.txt"

# Nomes de comandos aceitos pela parte do Joao.
c_addmorador:    .asciiz "addMorador"
c_rmvmorador:    .asciiz "rmvMorador"
c_addauto:       .asciiz "addAuto"
c_addauto_upper: .asciiz "AddAuto"
c_rmvauto:       .asciiz "rmvAuto"
c_limparap:      .asciiz "limparAp"
c_formatar:      .asciiz "formatar"
c_infoap:        .asciiz "infoAp"
c_infogeral:     .asciiz "infoGeral"
c_salvar:        .asciiz "salvar"
c_recarregar:    .asciiz "recarregar"

# Buffer recebe a linha digitada no terminal.
# O syscall 8 le no maximo 255 caracteres mais o terminador.
buffer:          .space 256

# Tokens armazena cinco enderecos de string:
# tokens[0] = comando; tokens[1..4] = opcoes.
.align 2
tokens:          .space 20

# Guarda quantos tokens foram encontrados pelo parser.
ntokens:         .word 0

# Area continua para 24 apartamentos de 300 bytes cada.
# A area comeca zerada, entao todos comecam sem moradores e sem autos.
aptos:           .space TOTAL_BYTES
buffer_arquivo:  .space TOTAL_BYTES


# ==========================================================
# CODIGO EXECUTAVEL
# ==========================================================

.text
.globl main


# ==========================================================
# SHELL E DESPACHANTE
# ==========================================================

main:
    # Na primeira execucao, tenta carregar os dados salvos anteriormente.
    jal  carregar_arquivo
loop:
    # Exibe o banner antes de esperar por um comando.
    li   $v0, 4    # Carrega o valor imediato no registrador de destino.
    la   $a0, banner    # Carrega o endereco do rotulo no registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.

    # Le uma linha do teclado para buffer.
    # $a0 = endereco do buffer; $a1 = tamanho maximo.
    li   $v0, 8    # Carrega o valor imediato no registrador de destino.
    la   $a0, buffer    # Carrega o endereco do rotulo no registrador de destino.
    li   $a1, 256    # Carrega o valor imediato no registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.

    # O syscall de leitura deixa o Enter na linha.
    # Remove esse caractere para facilitar as comparacoes.
    la   $a0, buffer    # Carrega o endereco do rotulo no registrador de destino.
    jal  remove_newline

    # Remove espacos que eventualmente ficaram no final da linha.
    la   $a0, buffer    # Carrega o endereco do rotulo no registrador de destino.
    jal  trim_direita

    # Se o primeiro byte for zero, o usuario so pressionou Enter.
    # Nesse caso, volta ao inicio sem imprimir erro.
    la   $t0, buffer    # Carrega o endereco do rotulo no registrador de destino.
    lb   $t1, 0($t0)    # Carrega um byte da memoria e estende o sinal para o registrador.
    beq  $t1, $zero, loop    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Divide a linha em comando e opcoes usando o delimitador " --".
    la   $a0, buffer    # Carrega o endereco do rotulo no registrador de destino.
    la   $a1, tokens    # Carrega o endereco do rotulo no registrador de destino.
    jal  split_opcoes

    # Salva a quantidade de tokens para os comandos consultarem depois.
    la   $t0, ntokens    # Carrega o endereco do rotulo no registrador de destino.
    sw   $v0, 0($t0)    # Grava uma palavra do registrador na memoria.

    # $s0 aponta para a tabela de comandos.
    # Cada registro tem dois enderecos: nome e funcao.
    la   $s0, tabela    # Carrega o endereco do rotulo no registrador de destino.

disp_loop:
    # Le o endereco do proximo nome de comando.
    lw   $a0, 0($s0)    # Carrega uma palavra da memoria para o registrador.

    # Nome zero marca o final da tabela.
    beq  $a0, $zero, disp_invalido    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Compara tokens[0] com o nome atual da tabela.
    jal  cmd_eh
    beq  $v0, $zero, disp_achou    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Cada registro ocupa 8 bytes: duas palavras de 4 bytes.
    addi $s0, $s0, 8    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j    disp_loop

disp_achou:
    # Carrega o endereco da funcao associada ao comando.
    lw   $t0, 4($s0)    # Carrega uma palavra da memoria para o registrador.

    # Chama a funcao do comando encontrado.
    jalr $t0    # Chama a rotina no endereco do registrador e salva o retorno em RA.

    # Quando o comando termina, espera a proxima linha.
    j    loop

disp_invalido:
    # Nenhum nome da tabela correspondeu ao comando digitado.
    la   $a0, msg_invalido    # Carrega o endereco do rotulo no registrador de destino.
    jal  imprime_str
    j    loop


# ==========================================================
# TABELA DE COMANDOS
# ==========================================================

# A tabela contem dados, nao instrucoes; por isso fica em .data.
# Cada comando ocupa duas palavras:
#   1. endereco da string com o nome
#   2. endereco da rotina que executa o comando
.data
.align 2
tabela:
    .word c_addmorador, cmd_add_morador
    .word c_rmvmorador, cmd_rmv_morador
    .word c_addauto, cmd_add_auto
    .word c_addauto_upper, cmd_add_auto
    .word c_rmvauto, cmd_rmv_auto
    .word c_limparap, cmd_limpar_ap
    .word c_formatar, cmd_formatar
    .word c_infoap, cmd_info_ap
    .word c_infogeral, cmd_info_geral
    .word c_salvar, cmd_salvar
    .word c_recarregar, cmd_recarregar
    .word 0                     # marca o fim da tabela

# As rotinas seguintes sao instrucoes executaveis.
.text


# ==========================================================
# HELPERS GERAIS
# ==========================================================

# imprime_str
# Entrada: $a0 = endereco de uma string terminada em zero.
# A rotina usa syscall 4 para imprimir a string.
imprime_str:
    li   $v0, 4    # Carrega o valor imediato no registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.
    jr   $ra    # Desvia para o endereco guardado no registrador.


# cmd_eh
# Entrada: $a0 = endereco do nome de comando da tabela.
# Retorno: $v0 = 0 se o comando digitado for igual ao nome recebido.
cmd_eh:
    # Esta rotina chama strcmp, entao salva o endereco de retorno.
    addi $sp, $sp, -4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw   $ra, 0($sp)    # Grava uma palavra do registrador na memoria.

    # strcmp recebe:
    #   $a0 = comando digitado, tokens[0]
    #   $a1 = nome consultado na tabela
    move $a1, $a0    # Copia o valor do registrador de origem para o registrador de destino.
    la   $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw   $a0, 0($t0)    # Carrega uma palavra da memoria para o registrador.
    jal  strcmp

    # Restaura o endereco de retorno e devolve o resultado.
    lw   $ra, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.


# checa_ntokens
# Entrada: $a0 = quantidade de tokens esperada.
# Retorno: $v0 = 1 se a quantidade estiver certa; 0 caso contrario.
checa_ntokens:
    # Compara a quantidade recebida com a quantidade guardada.
    la   $t0, ntokens    # Carrega o endereco do rotulo no registrador de destino.
    lw   $t0, 0($t0)    # Carrega uma palavra da memoria para o registrador.
    beq  $t0, $a0, cnt_ok    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Quantidade errada: mostra a mensagem de comando invalido.
    addi $sp, $sp, -4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw   $ra, 0($sp)    # Grava uma palavra do registrador na memoria.
    la   $a0, msg_invalido    # Carrega o endereco do rotulo no registrador de destino.
    jal  imprime_str
    lw   $ra, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.

    # Informa ao chamador que a quantidade nao bateu.
    li   $v0, 0    # Carrega o valor imediato no registrador de destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.

cnt_ok:
    li   $v0, 1    # Carrega o valor imediato no registrador de destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.


# obtem_ap
# Entrada: $a0 = string com o numero do AP.
# Retorno: $v0 = endereco do bloco do AP ou zero se invalido.
obtem_ap:
    # Salva $ra porque esta funcao chama outras funcoes.
    addi $sp, $sp, -4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw   $ra, 0($sp)    # Grava uma palavra do registrador na memoria.

    # Converte o numero do AP em indice 0..23.
    jal  ap_indice
    bltz $v0, obtem_ap_invalido    # Desvia para o rotulo quando o valor e menor que zero.

    # Converte o indice em endereco de memoria.
    move $a0, $v0    # Copia o valor do registrador de origem para o registrador de destino.
    jal  ap_endereco
    j    obtem_ap_fim

obtem_ap_invalido:
    # O indice negativo significa que o AP nao e valido.
    la   $a0, msg_ap_inval    # Carrega o endereco do rotulo no registrador de destino.
    jal  imprime_str
    li   $v0, 0    # Carrega o valor imediato no registrador de destino.

obtem_ap_fim:
    # Restaura o endereco de retorno.
    lw   $ra, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.


# zera_bloco
# Entrada:
#   $a0 = endereco inicial
#   $a1 = numero de bytes que devem ser zerados
zera_bloco:
    # Quando nao restarem bytes, termina.
    beq  $a1, $zero, zera_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Zera o byte atual.
    sb   $zero, 0($a0)    # Grava o byte menos significativo do registrador na memoria.

    # Avanca um byte e reduz a quantidade restante.
    addi $a0, $a0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    addi $a1, $a1, -1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j    zera_bloco

zera_fim:
    jr   $ra    # Desvia para o endereco guardado no registrador.


# limpa_autos
# Entrada: $a0 = endereco-base do apartamento.
# Zera os campos de tipo, quantidade e slots dos automoveis.
limpa_autos:
    addi $sp, $sp, -4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw   $ra, 0($sp)    # Grava uma palavra do registrador na memoria.

    # Os campos de automoveis comecam no offset OFF_TIPO.
    addi $a0, $a0, OFF_TIPO    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.

    # AUTOS_BYTES cobre ate o final dos 300 bytes do AP.
    li   $a1, AUTOS_BYTES    # Carrega o valor imediato no registrador de destino.
    jal  zera_bloco

    lw   $ra, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.


# ==========================================================
# CONVERSAO E ENDERECOS DE APARTAMENTOS
# ==========================================================

# atoi
# Converte uma string decimal em um inteiro.
# Entrada: $a0 = endereco da string.
# Retorno: $v0 = numero; -1 se vazio, invalido ou maior que 4 digitos.
atoi:
    li   $v0, 0                 # acumulador do numero
    li   $t2, 10                # base decimal
    li   $t3, 0                 # quantidade de digitos lidos

    # Uma string vazia nao representa um numero valido.
    lb   $t0, 0($a0)    # Carrega um byte da memoria e estende o sinal para o registrador.
    beq  $t0, $zero, atoi_erro    # Desvia para o rotulo quando os registradores comparados sao iguais.

atoi_loop:
    lb   $t0, 0($a0)    # Carrega um byte da memoria e estende o sinal para o registrador.
    beq  $t0, $zero, atoi_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Limita a entrada a quatro digitos.
    # Isso impede overflow para valores maiores.
    li   $t4, 4    # Carrega o valor imediato no registrador de destino.
    bge  $t3, $t4, atoi_erro    # Desvia para o rotulo quando o primeiro valor e maior ou igual ao segundo.

    # Confere se o caractere esta entre '0' e '9' em ASCII.
    li   $t1, 48    # Carrega o valor imediato no registrador de destino.
    blt  $t0, $t1, atoi_erro    # Desvia para o rotulo quando o primeiro valor e menor que o segundo.
    li   $t1, 57    # Carrega o valor imediato no registrador de destino.
    bgt  $t0, $t1, atoi_erro    # Desvia para o rotulo quando o primeiro valor e maior que o segundo.

    # Transforma o caractere ASCII em numero.
    addi $t0, $t0, -48    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.

    # Atualiza o acumulador: numero = numero * 10 + digito.
    mul  $v0, $v0, $t2    # Multiplica os operandos e grava o resultado no destino.
    add  $v0, $v0, $t0    # Soma os dois operandos e grava o resultado no destino.

    # Avanca para o proximo caractere.
    addi $t3, $t3, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    addi $a0, $a0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j    atoi_loop

atoi_fim:
    jr   $ra    # Desvia para o endereco guardado no registrador.

atoi_erro:
    li   $v0, -1    # Carrega o valor imediato no registrador de destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.


# ap_indice
# Converte o numero do apartamento em indice de 0 a 23.
# Exemplo: AP 1102 -> indice 21.
# Retorna -1 se o andar ou o numero do apartamento forem invalidos.
ap_indice:
    # Salva $ra porque esta rotina chama atoi.
    addi $sp, $sp, -4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw   $ra, 0($sp)    # Grava uma palavra do registrador na memoria.

    jal  atoi
    bltz $v0, ap_indice_erro    # Desvia para o rotulo quando o valor e menor que zero.

    # Dividindo por 100:
    #   quociente = andar
    #   resto = numero do AP naquele andar
    li   $t0, 100    # Carrega o valor imediato no registrador de destino.
    div  $v0, $t0    # Divide os valores; o quociente fica em LO e o resto em HI.
    mflo $t1                    # andar
    mfhi $t2                    # numero do AP no andar

    # O condominio tem andares de 1 a 12.
    li   $t3, 1    # Carrega o valor imediato no registrador de destino.
    blt  $t1, $t3, ap_indice_erro    # Desvia para o rotulo quando o primeiro valor e menor que o segundo.
    li   $t3, 12    # Carrega o valor imediato no registrador de destino.
    bgt  $t1, $t3, ap_indice_erro    # Desvia para o rotulo quando o primeiro valor e maior que o segundo.

    # Cada andar tem AP 1 e AP 2.
    li   $t3, 1    # Carrega o valor imediato no registrador de destino.
    blt  $t2, $t3, ap_indice_erro    # Desvia para o rotulo quando o primeiro valor e menor que o segundo.
    li   $t3, 2    # Carrega o valor imediato no registrador de destino.
    bgt  $t2, $t3, ap_indice_erro    # Desvia para o rotulo quando o primeiro valor e maior que o segundo.

    # Indice = (andar - 1) * 2 + (AP no andar - 1).
    addi $t1, $t1, -1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sll  $t1, $t1, 1    # Desloca os bits do registrador para a esquerda.
    addi $t2, $t2, -1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    add  $v0, $t1, $t2    # Soma os dois operandos e grava o resultado no destino.

    # Retorna o indice calculado.
    lw   $ra, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.

ap_indice_erro:
    # Valor negativo sinaliza que o AP nao e valido.
    li   $v0, -1    # Carrega o valor imediato no registrador de destino.
    lw   $ra, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.


# ap_endereco
# Entrada: $a0 = indice 0..23.
# Retorno: $v0 = endereco inicial do bloco do apartamento.
ap_endereco:
    # Cada AP ocupa AP_SIZE bytes.
    # Endereco = aptos + indice * AP_SIZE.
    li   $t0, AP_SIZE    # Carrega o valor imediato no registrador de destino.
    mul  $t0, $a0, $t0    # Multiplica os operandos e grava o resultado no destino.
    la   $v0, aptos    # Carrega o endereco do rotulo no registrador de destino.
    add  $v0, $v0, $t0    # Soma os dois operandos e grava o resultado no destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.


# indice_para_num
# Converte o indice interno para o numero mostrado ao usuario.
# Exemplo: indice 21 -> apartamento 1102.
indice_para_num:
    # Dividir o indice por 2 encontra o andar, comecando em zero.
    srl  $t0, $a0, 1    # Desloca os bits do registrador para a direita com zeros.
    addi $t0, $t0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    li   $t1, 100    # Carrega o valor imediato no registrador de destino.
    mul  $t0, $t0, $t1    # Multiplica os operandos e grava o resultado no destino.

    # O ultimo bit indica AP 1 ou AP 2.
    andi $t2, $a0, 1    # Faz AND bit a bit com o valor imediato e grava o resultado no destino.
    addi $t2, $t2, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    add  $v0, $t0, $t2    # Soma os dois operandos e grava o resultado no destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.


# ==========================================================
# ROTINAS DE STRINGS
# ==========================================================

# remove_newline
# Entrada: $a0 = endereco da linha.
# Substitui o primeiro LF (10) ou CR (13) por zero.
remove_newline:
rn_loop:
    lb   $t0, 0($a0)    # Carrega um byte da memoria e estende o sinal para o registrador.
    beq  $t0, $zero, rn_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.

    li   $t1, 10    # Carrega o valor imediato no registrador de destino.
    beq  $t0, $t1, rn_achou    # Desvia para o rotulo quando os registradores comparados sao iguais.
    li   $t1, 13    # Carrega o valor imediato no registrador de destino.
    beq  $t0, $t1, rn_achou    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Ainda nao chegou ao Enter: examina o proximo byte.
    addi $a0, $a0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j    rn_loop

rn_achou:
    # Byte zero marca o fim da string.
    sb   $zero, 0($a0)    # Grava o byte menos significativo do registrador na memoria.

rn_fim:
    jr   $ra    # Desvia para o endereco guardado no registrador.


# trim_direita
# Entrada: $a0 = endereco da string.
# Remove espacos ASCII (32) que estejam no final.
trim_direita:
    move $t0, $a0    # Copia o valor do registrador de origem para o registrador de destino.

td_busca_fim:
    # Avanca ate encontrar o terminador zero.
    lb   $t1, 0($t0)    # Carrega um byte da memoria e estende o sinal para o registrador.
    beq  $t1, $zero, td_remove    # Desvia para o rotulo quando os registradores comparados sao iguais.
    addi $t0, $t0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j    td_busca_fim

td_remove:
    # Nao pode recuar antes do primeiro byte.
    beq  $t0, $a0, td_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Olha o byte anterior ao terminador.
    addi $t0, $t0, -1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    lb   $t1, 0($t0)    # Carrega um byte da memoria e estende o sinal para o registrador.
    li   $t2, 32    # Carrega o valor imediato no registrador de destino.

    # Se nao for espaco, a limpeza terminou.
    bne  $t1, $t2, td_fim    # Desvia para o rotulo quando os registradores comparados sao diferentes.

    # Troca o espaco final por zero e verifica o anterior.
    sb   $zero, 0($t0)    # Grava o byte menos significativo do registrador na memoria.
    j    td_remove

td_fim:
    jr   $ra    # Desvia para o endereco guardado no registrador.


# strcmp
# Entradas: $a0 e $a1 apontam para duas strings.
# Retorna zero em $v0 se forem iguais; diferente de zero caso contrario.
strcmp:
strcmp_loop:
    lb   $t0, 0($a0)    # Carrega um byte da memoria e estende o sinal para o registrador.
    lb   $t1, 0($a1)    # Carrega um byte da memoria e estende o sinal para o registrador.

    # Um caractere diferente significa que as strings nao sao iguais.
    bne  $t0, $t1, strcmp_diferentes    # Desvia para o rotulo quando os registradores comparados sao diferentes.

    # Se ambos chegaram ao zero ao mesmo tempo, sao iguais.
    beq  $t0, $zero, strcmp_iguais    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Continua comparando o proximo caractere.
    addi $a0, $a0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    addi $a1, $a1, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j    strcmp_loop

strcmp_diferentes:
    # Qualquer valor diferente de zero indica desigualdade.
    sub  $v0, $t0, $t1    # Subtrai o segundo operando do primeiro e grava o resultado no destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.

strcmp_iguais:
    li   $v0, 0    # Carrega o valor imediato no registrador de destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.


# strlen
# Entrada: $a0 = endereco da string.
# Retorna em $v0 a quantidade de caracteres antes do zero.
strlen:
    li   $v0, 0    # Carrega o valor imediato no registrador de destino.

strlen_loop:
    lb   $t0, 0($a0)    # Carrega um byte da memoria e estende o sinal para o registrador.
    beq  $t0, $zero, strlen_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Conta o caractere e avanca para o proximo.
    addi $v0, $v0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    addi $a0, $a0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j    strlen_loop

strlen_fim:
    jr   $ra    # Desvia para o endereco guardado no registrador.


# strcpy
# Entradas:
#   $a0 = endereco de destino
#   $a1 = endereco da string de origem
# Copia tambem o byte zero final.
strcpy:
strcpy_loop:
    lb   $t0, 0($a1)    # Carrega um byte da memoria e estende o sinal para o registrador.
    sb   $t0, 0($a0)    # Grava o byte menos significativo do registrador na memoria.

    # Depois de copiar o zero, a copia terminou.
    beq  $t0, $zero, strcpy_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Avanca nas duas strings.
    addi $a0, $a0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    addi $a1, $a1, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j    strcpy_loop

strcpy_fim:
    jr   $ra    # Desvia para o endereco guardado no registrador.


# split_opcoes
# Entradas:
#   $a0 = endereco da linha
#   $a1 = endereco do vetor tokens
# Retorno:
#   $v0 = quantidade de tokens
# O separador de opcoes e espaco + dois hifens: " --".
# Nomes com espacos internos, como "Claude Shannon", permanecem juntos.
split_opcoes:
    # O primeiro token comeca no inicio da linha.
    sw   $a0, 0($a1)    # Grava uma palavra do registrador na memoria.
    addi $a1, $a1, 4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    li   $v0, 1    # Carrega o valor imediato no registrador de destino.

sp_loop:
    lb   $t0, 0($a0)    # Carrega um byte da memoria e estende o sinal para o registrador.
    beq  $t0, $zero, sp_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Procura o primeiro byte do separador: espaco ASCII 32.
    li   $t1, 32    # Carrega o valor imediato no registrador de destino.
    bne  $t0, $t1, sp_proximo    # Desvia para o rotulo quando os registradores comparados sao diferentes.

    # Confere se os dois bytes seguintes sao hifens ASCII 45.
    lb   $t2, 1($a0)    # Carrega um byte da memoria e estende o sinal para o registrador.
    li   $t3, 45    # Carrega o valor imediato no registrador de destino.
    bne  $t2, $t3, sp_proximo    # Desvia para o rotulo quando os registradores comparados sao diferentes.

    lb   $t2, 2($a0)    # Carrega um byte da memoria e estende o sinal para o registrador.
    bne  $t2, $t3, sp_proximo    # Desvia para o rotulo quando os registradores comparados sao diferentes.

    # O vetor comporta no maximo cinco tokens.
    # Valor 6 informa ao chamador que havia opcoes demais.
    li   $t4, 5    # Carrega o valor imediato no registrador de destino.
    beq  $v0, $t4, sp_excesso    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Encerra a string atual substituindo o espaco por zero.
    sb   $zero, 0($a0)    # Grava o byte menos significativo do registrador na memoria.

    # O novo token comeca depois do espaco e dos dois hifens.
    addi $t5, $a0, 3    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw   $t5, 0($a1)    # Grava uma palavra do registrador na memoria.

    # Prepara o endereco da proxima posicao do vetor.
    addi $a1, $a1, 4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.

    # Atualiza a contagem e pula o separador ja processado.
    addi $v0, $v0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    addi $a0, $a0, 3    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j    sp_loop

sp_proximo:
    # O byte atual nao iniciou o separador; examina o seguinte.
    addi $a0, $a0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j    sp_loop

sp_excesso:
    # Retorna seis sem escrever alem das cinco posicoes de tokens.
    li   $v0, 6    # Carrega o valor imediato no registrador de destino.

sp_fim:
    jr   $ra    # Desvia para o endereco guardado no registrador.


# ==========================================================
# COMANDO addMorador
# ==========================================================

# Formato:
# addMorador --<numero do AP> --<nome>
cmd_add_morador:
    # Reserva espaco na pilha e salva os registradores que serao usados.
    addi $sp, $sp, -12    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw   $ra, 8($sp)    # Grava uma palavra do registrador na memoria.
    sw   $s0, 4($sp)    # Grava uma palavra do registrador na memoria.
    sw   $s1, 0($sp)    # Grava uma palavra do registrador na memoria.

    # O comando requer tres tokens: nome do comando, AP e nome.
    li   $a0, 3    # Carrega o valor imediato no registrador de destino.
    jal  checa_ntokens
    beq  $v0, $zero, am_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Converte a opcao do AP em endereco de memoria.
    la   $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw   $a0, 4($t0)    # Carrega uma palavra da memoria para o registrador.
    jal  obtem_ap
    beq  $v0, $zero, am_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
    move $s0, $v0                # $s0 preserva o endereco-base do AP

    # Confere se o AP ja tem o limite de seis moradores.
    lw   $t0, 0($s0)    # Carrega uma palavra da memoria para o registrador.
    li   $t1, MAX_MORADORES    # Carrega o valor imediato no registrador de destino.
    bge  $t0, $t1, am_cheio    # Desvia para o rotulo quando o primeiro valor e maior ou igual ao segundo.

    # Obtem o endereco do nome digitado, que esta em tokens[2].
    la   $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw   $s1, 8($t0)             # $s1 preserva o endereco do nome

    # Nome vazio nao pode ser cadastrado.
    move $a0, $s1    # Copia o valor do registrador de origem para o registrador de destino.
    jal  strlen
    beq  $v0, $zero, am_nome_inv    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Cada campo comporta 32 bytes, incluindo o terminador.
    # Portanto, o texto pode ter no maximo 31 caracteres.
    li   $t1, NOME_SIZE    # Carrega o valor imediato no registrador de destino.
    bge  $v0, $t1, am_nome_inv    # Desvia para o rotulo quando o primeiro valor e maior ou igual ao segundo.

    # O destino e:
    # base do AP + offset dos nomes + quantidade atual * tamanho do campo.
    lw   $t0, 0($s0)    # Carrega uma palavra da memoria para o registrador.
    li   $t1, NOME_SIZE    # Carrega o valor imediato no registrador de destino.
    mul  $t1, $t0, $t1    # Multiplica os operandos e grava o resultado no destino.
    addi $a0, $s0, OFF_NOMES    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    add  $a0, $a0, $t1    # Soma os dois operandos e grava o resultado no destino.

    # Copia o nome do buffer para o espaco permanente do AP.
    move $a1, $s1    # Copia o valor do registrador de origem para o registrador de destino.
    jal  strcpy

    # So depois da copia aumenta a quantidade de moradores.
    lw   $t0, 0($s0)    # Carrega uma palavra da memoria para o registrador.
    addi $t0, $t0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw   $t0, 0($s0)    # Grava uma palavra do registrador na memoria.
    j    am_fim

am_cheio:
    # O apartamento ja atingiu o limite de moradores.
    la   $a0, msg_max_morad    # Carrega o endereco do rotulo no registrador de destino.
    jal  imprime_str
    j    am_fim

am_nome_inv:
    # O nome esta vazio ou nao cabe no campo reservado.
    la   $a0, msg_nome_inv    # Carrega o endereco do rotulo no registrador de destino.
    jal  imprime_str

am_fim:
    # Restaura os registradores e retorna ao despachante.
    lw   $s1, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    lw   $s0, 4($sp)    # Carrega uma palavra da memoria para o registrador.
    lw   $ra, 8($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 12    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.


# ==========================================================
# COMANDO rmvMorador
# ==========================================================

# Formato:
# rmvMorador --<numero do AP> --<nome>
cmd_rmv_morador:
    # Reserva espaco na pilha e salva os registradores usados.
    addi $sp, $sp, -20    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw   $ra, 16($sp)    # Grava uma palavra do registrador na memoria.
    sw   $s0, 12($sp)    # Grava uma palavra do registrador na memoria.
    sw   $s1, 8($sp)    # Grava uma palavra do registrador na memoria.
    sw   $s2, 4($sp)    # Grava uma palavra do registrador na memoria.
    sw   $s3, 0($sp)    # Grava uma palavra do registrador na memoria.

    # O comando requer tres tokens: nome do comando, AP e nome.
    li   $a0, 3    # Carrega o valor imediato no registrador de destino.
    jal  checa_ntokens
    beq  $v0, $zero, rm_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Converte o numero do AP em endereco de memoria.
    la   $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw   $a0, 4($t0)    # Carrega uma palavra da memoria para o registrador.
    jal  obtem_ap
    beq  $v0, $zero, rm_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
    move $s0, $v0                # $s0 = endereco-base do AP

    # Salva a quantidade atual de moradores e o nome procurado.
    lw   $s1, 0($s0)    # Carrega uma palavra da memoria para o registrador.
    la   $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw   $s3, 8($t0)             # $s3 = endereco do nome
    li   $s2, 0                  # $s2 = indice do nome examinado

rm_busca:
    # Se o indice chegou a quantidade, o nome nao foi encontrado.
    beq  $s2, $s1, rm_nao_achou    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Calcula o endereco do nome no indice atual.
    li   $t0, NOME_SIZE    # Carrega o valor imediato no registrador de destino.
    mul  $t0, $s2, $t0    # Multiplica os operandos e grava o resultado no destino.
    addi $a0, $s0, OFF_NOMES    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    add  $a0, $a0, $t0    # Soma os dois operandos e grava o resultado no destino.

    # Compara o nome guardado com o nome informado pelo usuario.
    move $a1, $s3    # Copia o valor do registrador de origem para o registrador de destino.
    jal  strcmp
    beq  $v0, $zero, rm_achou    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Continua procurando no proximo campo de nome.
    addi $s2, $s2, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j    rm_busca

rm_nao_achou:
    # Nenhum morador cadastrado tinha esse nome.
    la   $a0, msg_morad_nao    # Carrega o endereco do rotulo no registrador de destino.
    jal  imprime_str
    j    rm_fim

rm_achou:
    # Reduz a quantidade: ela passa a ser o ultimo indice ocupado.
    addi $s1, $s1, -1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.

rm_shift:
    # Se o removido era o ultimo, nao ha nomes para deslocar.
    beq  $s2, $s1, rm_zera    # Desvia para o rotulo quando os registradores comparados sao iguais.

    # Copia o proximo nome para o espaco atual, fechando o buraco.
    li   $t0, NOME_SIZE    # Carrega o valor imediato no registrador de destino.
    mul  $t0, $s2, $t0    # Multiplica os operandos e grava o resultado no destino.
    addi $a0, $s0, OFF_NOMES    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    add  $a0, $a0, $t0    # Soma os dois operandos e grava o resultado no destino.
    addi $a1, $a0, NOME_SIZE    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jal  strcpy

    # Continua ate chegar ao antigo ultimo nome.
    addi $s2, $s2, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j    rm_shift

rm_zera:
    # Limpa o ultimo campo, que ficou sem uso apos a remocao.
    li   $t0, NOME_SIZE    # Carrega o valor imediato no registrador de destino.
    mul  $t0, $s1, $t0    # Multiplica os operandos e grava o resultado no destino.
    addi $a0, $s0, OFF_NOMES    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    add  $a0, $a0, $t0    # Soma os dois operandos e grava o resultado no destino.
    li   $a1, NOME_SIZE    # Carrega o valor imediato no registrador de destino.
    jal  zera_bloco

    # Atualiza o contador de moradores do apartamento.
    sw   $s1, 0($s0)    # Grava uma palavra do registrador na memoria.

    # Se ainda ha moradores, os automoveis permanecem cadastrados.
    bne  $s1, $zero, rm_fim    # Desvia para o rotulo quando os registradores comparados sao diferentes.

    # Se o AP ficou vazio, a regra do projeto exige apagar os autos.
    move $a0, $s0    # Copia o valor do registrador de origem para o registrador de destino.
    jal  limpa_autos

rm_fim:
    # Restaura os registradores salvos e retorna ao despachante.
    lw   $s3, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    lw   $s2, 4($sp)    # Carrega uma palavra da memoria para o registrador.
    lw   $s1, 8($sp)    # Carrega uma palavra da memoria para o registrador.
    lw   $s0, 12($sp)    # Carrega uma palavra da memoria para o registrador.
    lw   $ra, 16($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 20    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr   $ra    # Desvia para o endereco guardado no registrador.

# Cadastro simples: addAuto --AP --c/m --modelo --placa
cmd_add_auto:
    addi $sp, $sp, -20    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw $ra, 16($sp)    # Grava uma palavra do registrador na memoria.
    sw $s0, 12($sp)    # Grava uma palavra do registrador na memoria.
    sw $s1, 8($sp)    # Grava uma palavra do registrador na memoria.
    sw $s2, 4($sp)    # Grava uma palavra do registrador na memoria.
    sw $s3, 0($sp)    # Grava uma palavra do registrador na memoria.
    li $a0, 5    # Carrega o valor imediato no registrador de destino.
    jal checa_ntokens
    beq $v0, $zero, aa_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
    la $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw $a0, 4($t0)    # Carrega uma palavra da memoria para o registrador.
    jal obtem_ap
    beq $v0, $zero, aa_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
    move $s0, $v0    # Copia o valor do registrador de origem para o registrador de destino.
    la $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw $a0, 8($t0)    # Carrega uma palavra da memoria para o registrador.
    la $a1, txt_c    # Carrega o endereco do rotulo no registrador de destino.
    jal strcmp
    beq $v0, $zero, aa_carro    # Desvia para o rotulo quando os registradores comparados sao iguais.
    la $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw $a0, 8($t0)    # Carrega uma palavra da memoria para o registrador.
    la $a1, txt_m    # Carrega o endereco do rotulo no registrador de destino.
    jal strcmp
    bne $v0, $zero, aa_tipo_invalido    # Desvia para o rotulo quando os registradores comparados sao diferentes.
    li $s1, 2    # Carrega o valor imediato no registrador de destino.
    j aa_limite
aa_carro:
    li $s1, 1    # Carrega o valor imediato no registrador de destino.
aa_limite:
    lw $s2, OFF_QTD($s0)    # Carrega uma palavra da memoria para o registrador.
    beq $s2, $zero, aa_campos    # Desvia para o rotulo quando os registradores comparados sao iguais.
    lw $t0, OFF_TIPO($s0)    # Carrega uma palavra da memoria para o registrador.
    bne $t0, $s1, aa_cheio    # Desvia para o rotulo quando os registradores comparados sao diferentes.
    li $t0, 1    # Carrega o valor imediato no registrador de destino.
    beq $s1, $t0, aa_cheio    # Desvia para o rotulo quando os registradores comparados sao iguais.
    li $t0, 2    # Carrega o valor imediato no registrador de destino.
    bge $s2, $t0, aa_cheio    # Desvia para o rotulo quando o primeiro valor e maior ou igual ao segundo.
aa_campos:
    la $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw $a0, 12($t0)    # Carrega uma palavra da memoria para o registrador.
    jal strlen
    beq $v0, $zero, aa_modelo    # Desvia para o rotulo quando os registradores comparados sao iguais.
    li $t0, AUTO_PLACA    # Carrega o valor imediato no registrador de destino.
    bge $v0, $t0, aa_modelo    # Desvia para o rotulo quando o primeiro valor e maior ou igual ao segundo.
    la $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw $a0, 16($t0)    # Carrega uma palavra da memoria para o registrador.
    jal strlen
    beq $v0, $zero, aa_placa    # Desvia para o rotulo quando os registradores comparados sao iguais.
    li $t0, PLACA_SIZE    # Carrega o valor imediato no registrador de destino.
    bge $v0, $t0, aa_placa    # Desvia para o rotulo quando o primeiro valor e maior ou igual ao segundo.
    li $t0, AUTO_SIZE    # Carrega o valor imediato no registrador de destino.
    mul $t0, $s2, $t0    # Multiplica os operandos e grava o resultado no destino.
    addi $s3, $s0, OFF_AUTO0    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    add $s3, $s3, $t0    # Soma os dois operandos e grava o resultado no destino.
    move $a0, $s3    # Copia o valor do registrador de origem para o registrador de destino.
    la $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw $a1, 12($t0)    # Carrega uma palavra da memoria para o registrador.
    jal strcpy
    addi $a0, $s3, AUTO_PLACA    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    la $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw $a1, 16($t0)    # Carrega uma palavra da memoria para o registrador.
    jal strcpy
    addi $s2, $s2, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw $s2, OFF_QTD($s0)    # Grava uma palavra do registrador na memoria.
    sw $s1, OFF_TIPO($s0)    # Grava uma palavra do registrador na memoria.
    j aa_fim
aa_tipo_invalido:
    la $a0, msg_tipo_inv    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    j aa_fim
aa_cheio:
    la $a0, msg_max_auto    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    j aa_fim
aa_modelo:
    la $a0, msg_modelo_inv    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    j aa_fim
aa_placa:
    la $a0, msg_placa_inv    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
aa_fim:
    lw $s3, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $s2, 4($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $s1, 8($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $s0, 12($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $ra, 16($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 20    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr $ra    # Desvia para o endereco guardado no registrador.

# Remove pela placa e compacta o segundo slot quando necessario.
cmd_rmv_auto:
    addi $sp, $sp, -20    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw $ra, 16($sp)    # Grava uma palavra do registrador na memoria.
    sw $s0, 12($sp)    # Grava uma palavra do registrador na memoria.
    sw $s1, 8($sp)    # Grava uma palavra do registrador na memoria.
    sw $s2, 4($sp)    # Grava uma palavra do registrador na memoria.
    sw $s3, 0($sp)    # Grava uma palavra do registrador na memoria.
    li $a0, 3    # Carrega o valor imediato no registrador de destino.
    jal checa_ntokens
    beq $v0, $zero, ra_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
    la $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw $a0, 4($t0)    # Carrega uma palavra da memoria para o registrador.
    jal obtem_ap
    beq $v0, $zero, ra_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
    move $s0, $v0    # Copia o valor do registrador de origem para o registrador de destino.
    lw $s1, OFF_QTD($s0)    # Carrega uma palavra da memoria para o registrador.
    la $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw $s3, 8($t0)    # Carrega uma palavra da memoria para o registrador.
    li $s2, 0    # Carrega o valor imediato no registrador de destino.
ra_busca:
    bge $s2, $s1, ra_nao    # Desvia para o rotulo quando o primeiro valor e maior ou igual ao segundo.
    li $t0, AUTO_SIZE    # Carrega o valor imediato no registrador de destino.
    mul $t0, $s2, $t0    # Multiplica os operandos e grava o resultado no destino.
    addi $a0, $s0, OFF_PLACA0    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    add $a0, $a0, $t0    # Soma os dois operandos e grava o resultado no destino.
    move $a1, $s3    # Copia o valor do registrador de origem para o registrador de destino.
    jal strcmp
    beq $v0, $zero, ra_achou    # Desvia para o rotulo quando os registradores comparados sao iguais.
    addi $s2, $s2, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j ra_busca
ra_nao:
    la $a0, msg_auto_nao    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    j ra_fim
ra_achou:
    beq $s2, $zero, ra_primeiro    # Desvia para o rotulo quando os registradores comparados sao iguais.
    addi $a0, $s0, OFF_AUTO1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    addi $a1, $s0, OFF_AUTO0    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    li $a2, AUTO_SIZE    # Carrega o valor imediato no registrador de destino.
ra_move:
    beq $a2, $zero, ra_primeiro    # Desvia para o rotulo quando os registradores comparados sao iguais.
    lb $t0, 0($a0)    # Carrega um byte da memoria e estende o sinal para o registrador.
    sb $t0, 0($a1)    # Grava o byte menos significativo do registrador na memoria.
    addi $a0, $a0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    addi $a1, $a1, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    addi $a2, $a2, -1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j ra_move
ra_primeiro:
    addi $s1, $s1, -1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    li $t0, AUTO_SIZE    # Carrega o valor imediato no registrador de destino.
    mul $t0, $s1, $t0    # Multiplica os operandos e grava o resultado no destino.
    addi $a0, $s0, OFF_AUTO0    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    add $a0, $a0, $t0    # Soma os dois operandos e grava o resultado no destino.
    li $a1, AUTO_SIZE    # Carrega o valor imediato no registrador de destino.
    jal zera_bloco
    sw $s1, OFF_QTD($s0)    # Grava uma palavra do registrador na memoria.
    bne $s1, $zero, ra_fim    # Desvia para o rotulo quando os registradores comparados sao diferentes.
    sw $zero, OFF_TIPO($s0)    # Grava uma palavra do registrador na memoria.
ra_fim:
    lw $s3, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $s2, 4($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $s1, 8($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $s0, 12($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $ra, 16($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 20    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr $ra    # Desvia para o endereco guardado no registrador.

cmd_limpar_ap:
    addi $sp, $sp, -4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw $ra, 0($sp)    # Grava uma palavra do registrador na memoria.
    li $a0, 2    # Carrega o valor imediato no registrador de destino.
    jal checa_ntokens
    beq $v0, $zero, cl_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
    la $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw $a0, 4($t0)    # Carrega uma palavra da memoria para o registrador.
    jal obtem_ap
    beq $v0, $zero, cl_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
    move $a0, $v0    # Copia o valor do registrador de origem para o registrador de destino.
    li $a1, AP_SIZE    # Carrega o valor imediato no registrador de destino.
    jal zera_bloco
cl_fim:
    lw $ra, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr $ra    # Desvia para o endereco guardado no registrador.

cmd_formatar:
    addi $sp, $sp, -4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw $ra, 0($sp)    # Grava uma palavra do registrador na memoria.
    li $a0, 1    # Carrega o valor imediato no registrador de destino.
    jal checa_ntokens
    beq $v0, $zero, cf_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
    la $a0, aptos    # Carrega o endereco do rotulo no registrador de destino.
    li $a1, TOTAL_BYTES    # Carrega o valor imediato no registrador de destino.
    jal zera_bloco
cf_fim:
    lw $ra, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr $ra    # Desvia para o endereco guardado no registrador.

# Consulta resumida: AP e moradores; autos aparecem quando cadastrados.
cmd_info_ap:
    addi $sp, $sp, -16    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw $ra, 12($sp)    # Grava uma palavra do registrador na memoria.
    sw $s0, 8($sp)    # Grava uma palavra do registrador na memoria.
    sw $s1, 4($sp)    # Grava uma palavra do registrador na memoria.
    sw $s2, 0($sp)    # Grava uma palavra do registrador na memoria.
    li $a0, 2    # Carrega o valor imediato no registrador de destino.
    jal checa_ntokens
    beq $v0, $zero, ci_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
    la $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw $a0, 4($t0)    # Carrega uma palavra da memoria para o registrador.
    la $a1, txt_all    # Carrega o endereco do rotulo no registrador de destino.
    jal strcmp
    beq $v0, $zero, ci_todos    # Desvia para o rotulo quando os registradores comparados sao iguais.
    la $t0, tokens    # Carrega o endereco do rotulo no registrador de destino.
    lw $a0, 4($t0)    # Carrega uma palavra da memoria para o registrador.
    jal ap_indice
    bltz $v0, ci_invalido    # Desvia para o rotulo quando o valor e menor que zero.
    move $s0, $v0    # Copia o valor do registrador de origem para o registrador de destino.
    addi $s1, $v0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j ci_loop
ci_todos:
    li $s0, 0    # Carrega o valor imediato no registrador de destino.
    li $s1, NUM_APS    # Carrega o valor imediato no registrador de destino.
ci_loop:
    bge $s0, $s1, ci_fim    # Desvia para o rotulo quando o primeiro valor e maior ou igual ao segundo.
    move $a0, $s0    # Copia o valor do registrador de origem para o registrador de destino.
    jal ap_endereco
    move $s2, $v0    # Copia o valor do registrador de origem para o registrador de destino.
    la $a0, txt_ap    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    move $a0, $s0    # Copia o valor do registrador de origem para o registrador de destino.
    jal indice_para_num
    move $a0, $v0    # Copia o valor do registrador de origem para o registrador de destino.
    li $v0, 1    # Carrega o valor imediato no registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.
    la $a0, txt_nl    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    lw $t0, 0($s2)    # Carrega uma palavra da memoria para o registrador.
    beq $t0, $zero, ci_vazio    # Desvia para o rotulo quando os registradores comparados sao iguais.
    la $a0, txt_morad    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    li $t1, 0    # Carrega o valor imediato no registrador de destino.
ci_moradores:
    bge $t1, $t0, ci_autos    # Desvia para o rotulo quando o primeiro valor e maior ou igual ao segundo.
    li $t3, NOME_SIZE    # Carrega o valor imediato no registrador de destino.
    mul $t3, $t1, $t3    # Multiplica os operandos e grava o resultado no destino.
    addi $a0, $s2, OFF_NOMES    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    add $a0, $a0, $t3    # Soma os dois operandos e grava o resultado no destino.
    jal imprime_str
    la $a0, txt_nl    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    addi $t1, $t1, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    lw $t0, 0($s2)    # Carrega uma palavra da memoria para o registrador.
    j ci_moradores
ci_autos:
    lw $t0, OFF_QTD($s2)    # Carrega uma palavra da memoria para o registrador.
    beq $t0, $zero, ci_proximo    # Desvia para o rotulo quando os registradores comparados sao iguais.
    lw $t1, OFF_TIPO($s2)    # Carrega uma palavra da memoria para o registrador.
    li $t3, 1    # Carrega o valor imediato no registrador de destino.
    bne $t1, $t3, ci_moto    # Desvia para o rotulo quando os registradores comparados sao diferentes.
    la $a0, txt_carro    # Carrega o endereco do rotulo no registrador de destino.
    j ci_tipo
ci_moto:
    la $a0, txt_moto    # Carrega o endereco do rotulo no registrador de destino.
ci_tipo:
    jal imprime_str
    li $t1, 0    # Carrega o valor imediato no registrador de destino.
ci_auto_loop:
    bge $t1, $t0, ci_fim_linha    # Desvia para o rotulo quando o primeiro valor e maior ou igual ao segundo.
ci_modelo:
    li $t3, AUTO_SIZE    # Carrega o valor imediato no registrador de destino.
    mul $t3, $t1, $t3    # Multiplica os operandos e grava o resultado no destino.
    addi $a0, $s2, OFF_AUTO0    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    add $a0, $a0, $t3    # Soma os dois operandos e grava o resultado no destino.
    jal imprime_str
    # A placa fica a AUTO_PLACA bytes depois do inicio do slot.
    la $a0, txt_sep    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    addi $a0, $s2, OFF_PLACA0    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    add $a0, $a0, $t3    # Soma os dois operandos e grava o resultado no destino.
    jal imprime_str
    la $a0, txt_nl    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    addi $t1, $t1, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    lw $t0, OFF_QTD($s2)    # Carrega uma palavra da memoria para o registrador.
    j ci_auto_loop
ci_fim_linha:
    la $a0, txt_nl    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    j ci_proximo
ci_vazio:
    la $a0, txt_vazio    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
ci_proximo:
    addi $s0, $s0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j ci_loop
ci_invalido:
    la $a0, msg_ap_inval    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
ci_fim:
    lw $s2, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $s1, 4($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $s0, 8($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $ra, 12($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 16    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr $ra    # Desvia para o endereco guardado no registrador.

cmd_info_geral:
    addi $sp, $sp, -12    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw $ra, 8($sp)    # Grava uma palavra do registrador na memoria.
    sw $s0, 4($sp)    # Grava uma palavra do registrador na memoria.
    sw $s1, 0($sp)    # Grava uma palavra do registrador na memoria.
    li $a0, 1    # Carrega o valor imediato no registrador de destino.
    jal checa_ntokens
    beq $v0, $zero, cg_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
    li $s0, 0    # Carrega o valor imediato no registrador de destino.
    li $s1, 0    # Carrega o valor imediato no registrador de destino.
cg_loop:
    li $t0, NUM_APS    # Carrega o valor imediato no registrador de destino.
    bge $s0, $t0, cg_resultado    # Desvia para o rotulo quando o primeiro valor e maior ou igual ao segundo.
    move $a0, $s0    # Copia o valor do registrador de origem para o registrador de destino.
    jal ap_endereco
    lw $t0, 0($v0)    # Carrega uma palavra da memoria para o registrador.
    beq $t0, $zero, cg_proximo    # Desvia para o rotulo quando os registradores comparados sao iguais.
    addi $s1, $s1, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
cg_proximo:
    addi $s0, $s0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j cg_loop
cg_resultado:
    # Percentual inteiro de APs ocupados: quantidade * 100 / 24.
    li $t0, 100    # Carrega o valor imediato no registrador de destino.
    mul $t0, $s1, $t0    # Multiplica os operandos e grava o resultado no destino.
    li $t1, NUM_APS    # Carrega o valor imediato no registrador de destino.
    div $t0, $t1    # Divide os valores; o quociente fica em LO e o resto em HI.
    mflo $t2    # Copia o quociente da operacao guardado em LO para o registrador.
    la $a0, txt_nvazios    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    move $a0, $s1    # Copia o valor do registrador de origem para o registrador de destino.
    li $v0, 1    # Carrega o valor imediato no registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.
    la $a0, txt_pa    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    move $a0, $t2    # Copia o valor do registrador de origem para o registrador de destino.
    li $v0, 1    # Carrega o valor imediato no registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.
    la $a0, txt_pf    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    la $a0, txt_nl    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    la $a0, txt_vazios    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    li $t0, NUM_APS    # Carrega o valor imediato no registrador de destino.
    subu $a0, $t0, $s1    # Subtrai sem sinal o segundo operando do primeiro e grava o resultado no destino.
    li $v0, 1    # Carrega o valor imediato no registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.
    la $a0, txt_pa    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
    li $t0, 100    # Carrega o valor imediato no registrador de destino.
    subu $a0, $t0, $t2    # Subtrai sem sinal o segundo operando do primeiro e grava o resultado no destino.
    li $v0, 1    # Carrega o valor imediato no registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.
    la $a0, txt_pf    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
cg_fim:
    lw $s1, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $s0, 4($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $ra, 8($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 12    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr $ra    # Desvia para o endereco guardado no registrador.

# Syscall 13/14 le para buffer temporario; so substitui aptos na leitura completa.
carregar_arquivo:
    addi $sp, $sp, -8    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw $ra, 4($sp)    # Grava uma palavra do registrador na memoria.
    sw $s0, 0($sp)    # Grava uma palavra do registrador na memoria.
    li $v0, 13    # Carrega o valor imediato no registrador de destino.
    la $a0, arq_nome    # Carrega o endereco do rotulo no registrador de destino.
    li $a1, 0    # Carrega o valor imediato no registrador de destino.
    li $a2, 0    # Carrega o valor imediato no registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.
    bltz $v0, ca_falha    # Desvia para o rotulo quando o valor e menor que zero.
    move $s0, $v0    # Copia o valor do registrador de origem para o registrador de destino.
    li $v0, 14    # Carrega o valor imediato no registrador de destino.
    move $a0, $s0    # Copia o valor do registrador de origem para o registrador de destino.
    la $a1, buffer_arquivo    # Carrega o endereco do rotulo no registrador de destino.
    li $a2, TOTAL_BYTES    # Carrega o valor imediato no registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.
    move $t0, $v0    # Copia o valor do registrador de origem para o registrador de destino.
    li $v0, 16    # Carrega o valor imediato no registrador de destino.
    move $a0, $s0    # Copia o valor do registrador de origem para o registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.
    li $t1, TOTAL_BYTES    # Carrega o valor imediato no registrador de destino.
    bne $t0, $t1, ca_falha    # Desvia para o rotulo quando os registradores comparados sao diferentes.
    la $a0, aptos    # Carrega o endereco do rotulo no registrador de destino.
    la $a1, buffer_arquivo    # Carrega o endereco do rotulo no registrador de destino.
    li $a2, TOTAL_BYTES    # Carrega o valor imediato no registrador de destino.
ca_copia:
    beq $a2, $zero, ca_ok    # Desvia para o rotulo quando os registradores comparados sao iguais.
    lb $t0, 0($a1)    # Carrega um byte da memoria e estende o sinal para o registrador.
    sb $t0, 0($a0)    # Grava o byte menos significativo do registrador na memoria.
    addi $a0, $a0, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    addi $a1, $a1, 1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    addi $a2, $a2, -1    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    j ca_copia
ca_ok:
    li $v0, 1    # Carrega o valor imediato no registrador de destino.
    j ca_fim
ca_falha:
    move $v0, $zero    # Copia o valor do registrador de origem para o registrador de destino.
ca_fim:
    lw $s0, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $ra, 4($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 8    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr $ra    # Desvia para o endereco guardado no registrador.

cmd_salvar:
    addi $sp, $sp, -8    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw $ra, 4($sp)    # Grava uma palavra do registrador na memoria.
    sw $s0, 0($sp)    # Grava uma palavra do registrador na memoria.
    li $a0, 1    # Carrega o valor imediato no registrador de destino.
    jal checa_ntokens
    beq $v0, $zero, cs_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
    li $v0, 13    # Carrega o valor imediato no registrador de destino.
    la $a0, arq_nome    # Carrega o endereco do rotulo no registrador de destino.
    li $a1, 1    # Carrega o valor imediato no registrador de destino.
    li $a2, 0    # Carrega o valor imediato no registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.
    bltz $v0, cs_erro    # Desvia para o rotulo quando o valor e menor que zero.
    move $s0, $v0    # Copia o valor do registrador de origem para o registrador de destino.
    li $v0, 15    # Carrega o valor imediato no registrador de destino.
    move $a0, $s0    # Copia o valor do registrador de origem para o registrador de destino.
    la $a1, aptos    # Carrega o endereco do rotulo no registrador de destino.
    li $a2, TOTAL_BYTES    # Carrega o valor imediato no registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.
    move $t0, $v0    # Copia o valor do registrador de origem para o registrador de destino.
    li $v0, 16    # Carrega o valor imediato no registrador de destino.
    move $a0, $s0    # Copia o valor do registrador de origem para o registrador de destino.
    syscall    # Executa o servico indicado pelo valor em V0.
    li $t1, TOTAL_BYTES    # Carrega o valor imediato no registrador de destino.
    beq $t0, $t1, cs_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
cs_erro:
    la $a0, msg_arq_erro    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
cs_fim:
    lw $s0, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    lw $ra, 4($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 8    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr $ra    # Desvia para o endereco guardado no registrador.

cmd_recarregar:
    addi $sp, $sp, -4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    sw $ra, 0($sp)    # Grava uma palavra do registrador na memoria.
    li $a0, 1    # Carrega o valor imediato no registrador de destino.
    jal checa_ntokens
    beq $v0, $zero, cr_fim    # Desvia para o rotulo quando os registradores comparados sao iguais.
    jal carregar_arquivo
    bne $v0, $zero, cr_fim    # Desvia para o rotulo quando os registradores comparados sao diferentes.
    la $a0, msg_arq_erro    # Carrega o endereco do rotulo no registrador de destino.
    jal imprime_str
cr_fim:
    lw $ra, 0($sp)    # Carrega uma palavra da memoria para o registrador.
    addi $sp, $sp, 4    # Soma o valor imediato ao registrador de origem e grava o resultado no destino.
    jr $ra    # Desvia para o endereco guardado no registrador.
