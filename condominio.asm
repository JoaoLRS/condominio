# ==========================================================
# CONSTANTES DO PROJETO
# ==========================================================

.eqv NUM_APS        24       # 12 andares x 2 apartamentos por andar
.eqv AP_SIZE        300      # tamanho, em bytes, reservado para cada AP
.eqv TOTAL_BYTES    7200     # 24 x 300 bytes
.eqv MAX_MORADORES  6        # limite de moradores em cada AP
.eqv NOME_SIZE      32       # espaço fixo de cada nome, incluindo o zero final
.eqv OFF_NOMES      4        # nomes começam 4 bytes depois do início do AP
.eqv OFF_TIPO       196      # campo usado pelos automóveis
.eqv AUTOS_BYTES    104      # 4 bytes de tipo + 4 de quantidade + 96 de slots


# ==========================================================
# DADOS DO PROGRAMA
# ==========================================================

.data

# Banner mostrado antes de cada entrada.
# JA corresponde às iniciais de João e Alisson.
banner:          .asciiz "JA-shell>> "

# Mensagens utilizadas pelas rotinas deste arquivo.
msg_invalido:    .asciiz "Comando invalido\n"
msg_ap_inval:    .asciiz "Falha: AP invalido\n"
msg_max_morad:   .asciiz "Falha: AP com numero max de moradores\n"
msg_morad_nao:   .asciiz "Falha: morador nao encontrado\n"
msg_nome_inv:    .asciiz "Falha: nome invalido\n"

# Nomes de comandos aceitos pela parte do João.
c_addmorador:    .asciiz "addMorador"
c_rmvmorador:    .asciiz "rmvMorador"

# Buffer recebe a linha digitada no terminal.
# O syscall 8 lê no máximo 255 caracteres mais o terminador.
buffer:          .space 256

# Tokens armazena cinco endereços de string:
# tokens[0] = comando; tokens[1..4] = opções.
.align 2
tokens:          .space 20

# Guarda quantos tokens foram encontrados pelo parser.
ntokens:         .word 0

# Área contínua para 24 apartamentos de 300 bytes cada.
# A área começa zerada, então todos começam sem moradores e sem autos.
aptos:           .space TOTAL_BYTES


# ==========================================================
# CÓDIGO EXECUTÁVEL
# ==========================================================

.text
.globl main


# ==========================================================
# SHELL E DESPACHANTE
# ==========================================================

main:
loop:
    # Exibe o banner antes de esperar por um comando.
    li   $v0, 4
    la   $a0, banner
    syscall

    # Lê uma linha do teclado para buffer.
    # $a0 = endereço do buffer; $a1 = tamanho máximo.
    li   $v0, 8
    la   $a0, buffer
    li   $a1, 256
    syscall

    # O syscall de leitura deixa o Enter na linha.
    # Remove esse caractere para facilitar as comparações.
    la   $a0, buffer
    jal  remove_newline

    # Remove espaços que eventualmente ficaram no final da linha.
    la   $a0, buffer
    jal  trim_direita

    # Se o primeiro byte for zero, o usuário só pressionou Enter.
    # Nesse caso, volta ao início sem imprimir erro.
    la   $t0, buffer
    lb   $t1, 0($t0)
    beq  $t1, $zero, loop

    # Divide a linha em comando e opções usando o delimitador " --".
    la   $a0, buffer
    la   $a1, tokens
    jal  split_opcoes

    # Salva a quantidade de tokens para os comandos consultarem depois.
    la   $t0, ntokens
    sw   $v0, 0($t0)

    # $s0 aponta para a tabela de comandos.
    # Cada registro tem dois endereços: nome e função.
    la   $s0, tabela

disp_loop:
    # Lê o endereço do próximo nome de comando.
    lw   $a0, 0($s0)

    # Nome zero marca o final da tabela.
    beq  $a0, $zero, disp_invalido

    # Compara tokens[0] com o nome atual da tabela.
    jal  cmd_eh
    beq  $v0, $zero, disp_achou

    # Cada registro ocupa 8 bytes: duas palavras de 4 bytes.
    addi $s0, $s0, 8
    j    disp_loop

disp_achou:
    # Carrega o endereço da função associada ao comando.
    lw   $t0, 4($s0)

    # Chama a função do comando encontrado.
    jalr $t0

    # Quando o comando termina, espera a próxima linha.
    j    loop

disp_invalido:
    # Nenhum nome da tabela correspondeu ao comando digitado.
    la   $a0, msg_invalido
    jal  imprime_str
    j    loop


# ==========================================================
# TABELA DE COMANDOS
# ==========================================================

# A tabela contém dados, não instruções; por isso fica em .data.
# Cada comando ocupa duas palavras:
#   1. endereço da string com o nome
#   2. endereço da rotina que executa o comando
.data
.align 2
tabela:
    .word c_addmorador, cmd_add_morador
    .word c_rmvmorador, cmd_rmv_morador
    .word 0                     # marca o fim da tabela

# As rotinas seguintes são instruções executáveis.
.text


# ==========================================================
# HELPERS GERAIS
# ==========================================================

# imprime_str
# Entrada: $a0 = endereço de uma string terminada em zero.
# A rotina usa syscall 4 para imprimir a string.
imprime_str:
    li   $v0, 4
    syscall
    jr   $ra


# cmd_eh
# Entrada: $a0 = endereço do nome de comando da tabela.
# Retorno: $v0 = 0 se o comando digitado for igual ao nome recebido.
cmd_eh:
    # Esta rotina chama strcmp, então salva o endereço de retorno.
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # strcmp recebe:
    #   $a0 = comando digitado, tokens[0]
    #   $a1 = nome consultado na tabela
    move $a1, $a0
    la   $t0, tokens
    lw   $a0, 0($t0)
    jal  strcmp

    # Restaura o endereço de retorno e devolve o resultado.
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


# checa_ntokens
# Entrada: $a0 = quantidade de tokens esperada.
# Retorno: $v0 = 1 se a quantidade estiver certa; 0 caso contrário.
checa_ntokens:
    # Compara a quantidade recebida com a quantidade guardada.
    la   $t0, ntokens
    lw   $t0, 0($t0)
    beq  $t0, $a0, cnt_ok

    # Quantidade errada: mostra a mensagem de comando inválido.
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    la   $a0, msg_invalido
    jal  imprime_str
    lw   $ra, 0($sp)
    addi $sp, $sp, 4

    # Informa ao chamador que a quantidade não bateu.
    li   $v0, 0
    jr   $ra

cnt_ok:
    li   $v0, 1
    jr   $ra


# obtem_ap
# Entrada: $a0 = string com o número do AP.
# Retorno: $v0 = endereço do bloco do AP ou zero se inválido.
obtem_ap:
    # Salva $ra porque esta função chama outras funções.
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # Converte o número do AP em índice 0..23.
    jal  ap_indice
    bltz $v0, obtem_ap_invalido

    # Converte o índice em endereço de memória.
    move $a0, $v0
    jal  ap_endereco
    j    obtem_ap_fim

obtem_ap_invalido:
    # O índice negativo significa que o AP não é válido.
    la   $a0, msg_ap_inval
    jal  imprime_str
    li   $v0, 0

obtem_ap_fim:
    # Restaura o endereço de retorno.
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


# zera_bloco
# Entrada:
#   $a0 = endereço inicial
#   $a1 = número de bytes que devem ser zerados
zera_bloco:
    # Quando não restarem bytes, termina.
    beq  $a1, $zero, zera_fim

    # Zera o byte atual.
    sb   $zero, 0($a0)

    # Avança um byte e reduz a quantidade restante.
    addi $a0, $a0, 1
    addi $a1, $a1, -1
    j    zera_bloco

zera_fim:
    jr   $ra


# limpa_autos
# Entrada: $a0 = endereço-base do apartamento.
# Zera os campos de tipo, quantidade e slots dos automóveis.
limpa_autos:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # Os campos de automóveis começam no offset OFF_TIPO.
    addi $a0, $a0, OFF_TIPO

    # AUTOS_BYTES cobre até o final dos 300 bytes do AP.
    li   $a1, AUTOS_BYTES
    jal  zera_bloco

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


# ==========================================================
# CONVERSÃO E ENDEREÇOS DE APARTAMENTOS
# ==========================================================

# atoi
# Converte uma string decimal em um inteiro.
# Entrada: $a0 = endereço da string.
# Retorno: $v0 = número; -1 se vazio, inválido ou maior que 4 dígitos.
atoi:
    li   $v0, 0                 # acumulador do número
    li   $t2, 10                # base decimal
    li   $t3, 0                 # quantidade de dígitos lidos

    # Uma string vazia não representa um número válido.
    lb   $t0, 0($a0)
    beq  $t0, $zero, atoi_erro

atoi_loop:
    lb   $t0, 0($a0)
    beq  $t0, $zero, atoi_fim

    # Limita a entrada a quatro dígitos.
    # Isso impede overflow para valores maiores.
    li   $t4, 4
    bge  $t3, $t4, atoi_erro

    # Confere se o caractere está entre '0' e '9' em ASCII.
    li   $t1, 48
    blt  $t0, $t1, atoi_erro
    li   $t1, 57
    bgt  $t0, $t1, atoi_erro

    # Transforma o caractere ASCII em número.
    addi $t0, $t0, -48

    # Atualiza o acumulador: número = número * 10 + dígito.
    mul  $v0, $v0, $t2
    add  $v0, $v0, $t0

    # Avança para o próximo caractere.
    addi $t3, $t3, 1
    addi $a0, $a0, 1
    j    atoi_loop

atoi_fim:
    jr   $ra

atoi_erro:
    li   $v0, -1
    jr   $ra


# ap_indice
# Converte o número do apartamento em índice de 0 a 23.
# Exemplo: AP 1102 -> índice 21.
# Retorna -1 se o andar ou o número do apartamento forem inválidos.
ap_indice:
    # Salva $ra porque esta rotina chama atoi.
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    jal  atoi
    bltz $v0, ap_indice_erro

    # Dividindo por 100:
    #   quociente = andar
    #   resto = número do AP naquele andar
    li   $t0, 100
    div  $v0, $t0
    mflo $t1                    # andar
    mfhi $t2                    # número do AP no andar

    # O condomínio tem andares de 1 a 12.
    li   $t3, 1
    blt  $t1, $t3, ap_indice_erro
    li   $t3, 12
    bgt  $t1, $t3, ap_indice_erro

    # Cada andar tem AP 1 e AP 2.
    li   $t3, 1
    blt  $t2, $t3, ap_indice_erro
    li   $t3, 2
    bgt  $t2, $t3, ap_indice_erro

    # Índice = (andar - 1) * 2 + (AP no andar - 1).
    addi $t1, $t1, -1
    sll  $t1, $t1, 1
    addi $t2, $t2, -1
    add  $v0, $t1, $t2

    # Retorna o índice calculado.
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

ap_indice_erro:
    # Valor negativo sinaliza que o AP não é válido.
    li   $v0, -1
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


# ap_endereco
# Entrada: $a0 = índice 0..23.
# Retorno: $v0 = endereço inicial do bloco do apartamento.
ap_endereco:
    # Cada AP ocupa AP_SIZE bytes.
    # Endereço = aptos + índice * AP_SIZE.
    li   $t0, AP_SIZE
    mul  $t0, $a0, $t0
    la   $v0, aptos
    add  $v0, $v0, $t0
    jr   $ra


# indice_para_num
# Converte o índice interno para o número mostrado ao usuário.
# Exemplo: índice 21 -> apartamento 1102.
indice_para_num:
    # Dividir o índice por 2 encontra o andar, começando em zero.
    srl  $t0, $a0, 1
    addi $t0, $t0, 1
    li   $t1, 100
    mul  $t0, $t0, $t1

    # O último bit indica AP 1 ou AP 2.
    andi $t2, $a0, 1
    addi $t2, $t2, 1
    add  $v0, $t0, $t2
    jr   $ra


# ==========================================================
# ROTINAS DE STRINGS
# ==========================================================

# remove_newline
# Entrada: $a0 = endereço da linha.
# Substitui o primeiro LF (10) ou CR (13) por zero.
remove_newline:
rn_loop:
    lb   $t0, 0($a0)
    beq  $t0, $zero, rn_fim

    li   $t1, 10
    beq  $t0, $t1, rn_achou
    li   $t1, 13
    beq  $t0, $t1, rn_achou

    # Ainda não chegou ao Enter: examina o próximo byte.
    addi $a0, $a0, 1
    j    rn_loop

rn_achou:
    # Byte zero marca o fim da string.
    sb   $zero, 0($a0)

rn_fim:
    jr   $ra


# trim_direita
# Entrada: $a0 = endereço da string.
# Remove espaços ASCII (32) que estejam no final.
trim_direita:
    move $t0, $a0

td_busca_fim:
    # Avança até encontrar o terminador zero.
    lb   $t1, 0($t0)
    beq  $t1, $zero, td_remove
    addi $t0, $t0, 1
    j    td_busca_fim

td_remove:
    # Não pode recuar antes do primeiro byte.
    beq  $t0, $a0, td_fim

    # Olha o byte anterior ao terminador.
    addi $t0, $t0, -1
    lb   $t1, 0($t0)
    li   $t2, 32

    # Se não for espaço, a limpeza terminou.
    bne  $t1, $t2, td_fim

    # Troca o espaço final por zero e verifica o anterior.
    sb   $zero, 0($t0)
    j    td_remove

td_fim:
    jr   $ra


# strcmp
# Entradas: $a0 e $a1 apontam para duas strings.
# Retorna zero em $v0 se forem iguais; diferente de zero caso contrário.
strcmp:
strcmp_loop:
    lb   $t0, 0($a0)
    lb   $t1, 0($a1)

    # Um caractere diferente significa que as strings não são iguais.
    bne  $t0, $t1, strcmp_diferentes

    # Se ambos chegaram ao zero ao mesmo tempo, são iguais.
    beq  $t0, $zero, strcmp_iguais

    # Continua comparando o próximo caractere.
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    j    strcmp_loop

strcmp_diferentes:
    # Qualquer valor diferente de zero indica desigualdade.
    sub  $v0, $t0, $t1
    jr   $ra

strcmp_iguais:
    li   $v0, 0
    jr   $ra


# strlen
# Entrada: $a0 = endereço da string.
# Retorna em $v0 a quantidade de caracteres antes do zero.
strlen:
    li   $v0, 0

strlen_loop:
    lb   $t0, 0($a0)
    beq  $t0, $zero, strlen_fim

    # Conta o caractere e avança para o próximo.
    addi $v0, $v0, 1
    addi $a0, $a0, 1
    j    strlen_loop

strlen_fim:
    jr   $ra


# strcpy
# Entradas:
#   $a0 = endereço de destino
#   $a1 = endereço da string de origem
# Copia também o byte zero final.
strcpy:
strcpy_loop:
    lb   $t0, 0($a1)
    sb   $t0, 0($a0)

    # Depois de copiar o zero, a cópia terminou.
    beq  $t0, $zero, strcpy_fim

    # Avança nas duas strings.
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    j    strcpy_loop

strcpy_fim:
    jr   $ra


# split_opcoes
# Entradas:
#   $a0 = endereço da linha
#   $a1 = endereço do vetor tokens
# Retorno:
#   $v0 = quantidade de tokens
# O separador de opções é espaço + dois hífens: " --".
# Nomes com espaços internos, como "Claude Shannon", permanecem juntos.
split_opcoes:
    # O primeiro token começa no início da linha.
    sw   $a0, 0($a1)
    addi $a1, $a1, 4
    li   $v0, 1

sp_loop:
    lb   $t0, 0($a0)
    beq  $t0, $zero, sp_fim

    # Procura o primeiro byte do separador: espaço ASCII 32.
    li   $t1, 32
    bne  $t0, $t1, sp_proximo

    # Confere se os dois bytes seguintes são hífens ASCII 45.
    lb   $t2, 1($a0)
    li   $t3, 45
    bne  $t2, $t3, sp_proximo

    lb   $t2, 2($a0)
    bne  $t2, $t3, sp_proximo

    # O vetor comporta no máximo cinco tokens.
    # Valor 6 informa ao chamador que havia opções demais.
    li   $t4, 5
    beq  $v0, $t4, sp_excesso

    # Encerra a string atual substituindo o espaço por zero.
    sb   $zero, 0($a0)

    # O novo token começa depois do espaço e dos dois hífens.
    addi $t5, $a0, 3
    sw   $t5, 0($a1)

    # Prepara o endereço da próxima posição do vetor.
    addi $a1, $a1, 4

    # Atualiza a contagem e pula o separador já processado.
    addi $v0, $v0, 1
    addi $a0, $a0, 3
    j    sp_loop

sp_proximo:
    # O byte atual não iniciou o separador; examina o seguinte.
    addi $a0, $a0, 1
    j    sp_loop

sp_excesso:
    # Retorna seis sem escrever além das cinco posições de tokens.
    li   $v0, 6

sp_fim:
    jr   $ra


# ==========================================================
# COMANDO addMorador
# ==========================================================

# Formato:
# addMorador --<número do AP> --<nome>
cmd_add_morador:
    # Reserva espaço na pilha e salva os registradores que serão usados.
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)

    # O comando requer três tokens: nome do comando, AP e nome.
    li   $a0, 3
    jal  checa_ntokens
    beq  $v0, $zero, am_fim

    # Converte a opção do AP em endereço de memória.
    la   $t0, tokens
    lw   $a0, 4($t0)
    jal  obtem_ap
    beq  $v0, $zero, am_fim
    move $s0, $v0                # $s0 preserva o endereço-base do AP

    # Confere se o AP já tem o limite de seis moradores.
    lw   $t0, 0($s0)
    li   $t1, MAX_MORADORES
    bge  $t0, $t1, am_cheio

    # Obtém o endereço do nome digitado, que está em tokens[2].
    la   $t0, tokens
    lw   $s1, 8($t0)             # $s1 preserva o endereço do nome

    # Nome vazio não pode ser cadastrado.
    move $a0, $s1
    jal  strlen
    beq  $v0, $zero, am_nome_inv

    # Cada campo comporta 32 bytes, incluindo o terminador.
    # Portanto, o texto pode ter no máximo 31 caracteres.
    li   $t1, NOME_SIZE
    bge  $v0, $t1, am_nome_inv

    # O destino é:
    # base do AP + offset dos nomes + quantidade atual * tamanho do campo.
    lw   $t0, 0($s0)
    li   $t1, NOME_SIZE
    mul  $t1, $t0, $t1
    addi $a0, $s0, OFF_NOMES
    add  $a0, $a0, $t1

    # Copia o nome do buffer para o espaço permanente do AP.
    move $a1, $s1
    jal  strcpy

    # Só depois da cópia aumenta a quantidade de moradores.
    lw   $t0, 0($s0)
    addi $t0, $t0, 1
    sw   $t0, 0($s0)
    j    am_fim

am_cheio:
    # O apartamento já atingiu o limite de moradores.
    la   $a0, msg_max_morad
    jal  imprime_str
    j    am_fim

am_nome_inv:
    # O nome está vazio ou não cabe no campo reservado.
    la   $a0, msg_nome_inv
    jal  imprime_str

am_fim:
    # Restaura os registradores e retorna ao despachante.
    lw   $s1, 0($sp)
    lw   $s0, 4($sp)
    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra


# ==========================================================
# COMANDO rmvMorador
# ==========================================================

# Formato:
# rmvMorador --<número do AP> --<nome>
cmd_rmv_morador:
    # Reserva espaço na pilha e salva os registradores usados.
    addi $sp, $sp, -20
    sw   $ra, 16($sp)
    sw   $s0, 12($sp)
    sw   $s1, 8($sp)
    sw   $s2, 4($sp)
    sw   $s3, 0($sp)

    # O comando requer três tokens: nome do comando, AP e nome.
    li   $a0, 3
    jal  checa_ntokens
    beq  $v0, $zero, rm_fim

    # Converte o número do AP em endereço de memória.
    la   $t0, tokens
    lw   $a0, 4($t0)
    jal  obtem_ap
    beq  $v0, $zero, rm_fim
    move $s0, $v0                # $s0 = endereço-base do AP

    # Salva a quantidade atual de moradores e o nome procurado.
    lw   $s1, 0($s0)
    la   $t0, tokens
    lw   $s3, 8($t0)             # $s3 = endereço do nome
    li   $s2, 0                  # $s2 = índice do nome examinado

rm_busca:
    # Se o índice chegou à quantidade, o nome não foi encontrado.
    beq  $s2, $s1, rm_nao_achou

    # Calcula o endereço do nome no índice atual.
    li   $t0, NOME_SIZE
    mul  $t0, $s2, $t0
    addi $a0, $s0, OFF_NOMES
    add  $a0, $a0, $t0

    # Compara o nome guardado com o nome informado pelo usuário.
    move $a1, $s3
    jal  strcmp
    beq  $v0, $zero, rm_achou

    # Continua procurando no próximo campo de nome.
    addi $s2, $s2, 1
    j    rm_busca

rm_nao_achou:
    # Nenhum morador cadastrado tinha esse nome.
    la   $a0, msg_morad_nao
    jal  imprime_str
    j    rm_fim

rm_achou:
    # Reduz a quantidade: ela passa a ser o último índice ocupado.
    addi $s1, $s1, -1

rm_shift:
    # Se o removido era o último, não há nomes para deslocar.
    beq  $s2, $s1, rm_zera

    # Copia o próximo nome para o espaço atual, fechando o buraco.
    li   $t0, NOME_SIZE
    mul  $t0, $s2, $t0
    addi $a0, $s0, OFF_NOMES
    add  $a0, $a0, $t0
    addi $a1, $a0, NOME_SIZE
    jal  strcpy

    # Continua até chegar ao antigo último nome.
    addi $s2, $s2, 1
    j    rm_shift

rm_zera:
    # Limpa o último campo, que ficou sem uso após a remoção.
    li   $t0, NOME_SIZE
    mul  $t0, $s1, $t0
    addi $a0, $s0, OFF_NOMES
    add  $a0, $a0, $t0
    li   $a1, NOME_SIZE
    jal  zera_bloco

    # Atualiza o contador de moradores do apartamento.
    sw   $s1, 0($s0)

    # Se ainda há moradores, os automóveis permanecem cadastrados.
    bne  $s1, $zero, rm_fim

    # Se o AP ficou vazio, a regra do projeto exige apagar os autos.
    move $a0, $s0
    jal  limpa_autos

rm_fim:
    # Restaura os registradores salvos e retorna ao despachante.
    lw   $s3, 0($sp)
    lw   $s2, 4($sp)
    lw   $s1, 8($sp)
    lw   $s0, 12($sp)
    lw   $ra, 16($sp)
    addi $sp, $sp, 20
    jr   $ra