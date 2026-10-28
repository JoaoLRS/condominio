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
txt_carro:       .asciiz "Carro: "
txt_moto:        .asciiz "Moto: "
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
arq_nome:        .asciiz "condominio.txt"

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

# ?rea continua para 24 apartamentos de 300 bytes cada.
# A area comeca zerada, entao todos comecam sem moradores e sem autos.
aptos:           .space TOTAL_BYTES
buffer_arquivo:  .space TOTAL_BYTES


# ==========================================================
# CODIGO EXECUT?VEL
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
    li   $v0, 4
    la   $a0, banner
    syscall

    # Le uma linha do teclado para buffer.
    # $a0 = endereco do buffer; $a1 = tamanho maximo.
    li   $v0, 8
    la   $a0, buffer
    li   $a1, 256
    syscall

    # O syscall de leitura deixa o Enter na linha.
    # Remove esse caractere para facilitar as comparacoes.
    la   $a0, buffer
    jal  remove_newline

    # Remove espacos que eventualmente ficaram no final da linha.
    la   $a0, buffer
    jal  trim_direita

    # Se o primeiro byte for zero, o usuario so pressionou Enter.
    # Nesse caso, volta ao inicio sem imprimir erro.
    la   $t0, buffer
    lb   $t1, 0($t0)
    beq  $t1, $zero, loop

    # Divide a linha em comando e opcoes usando o delimitador " --".
    la   $a0, buffer
    la   $a1, tokens
    jal  split_opcoes

    # Salva a quantidade de tokens para os comandos consultarem depois.
    la   $t0, ntokens
    sw   $v0, 0($t0)

    # $s0 aponta para a tabela de comandos.
    # Cada registro tem dois enderecos: nome e funcao.
    la   $s0, tabela

disp_loop:
    # Le o endereco do proximo nome de comando.
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
    # Carrega o endereco da funcao associada ao comando.
    lw   $t0, 4($s0)

    # Chama a funcao do comando encontrado.
    jalr $t0

    # Quando o comando termina, espera a proxima linha.
    j    loop

disp_invalido:
    # Nenhum nome da tabela correspondeu ao comando digitado.
    la   $a0, msg_invalido
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
    li   $v0, 4
    syscall
    jr   $ra


# cmd_eh
# Entrada: $a0 = endereco do nome de comando da tabela.
# Retorno: $v0 = 0 se o comando digitado for igual ao nome recebido.
cmd_eh:
    # Esta rotina chama strcmp, entao salva o endereco de retorno.
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # strcmp recebe:
    #   $a0 = comando digitado, tokens[0]
    #   $a1 = nome consultado na tabela
    move $a1, $a0
    la   $t0, tokens
    lw   $a0, 0($t0)
    jal  strcmp

    # Restaura o endereco de retorno e devolve o resultado.
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


# checa_ntokens
# Entrada: $a0 = quantidade de tokens esperada.
# Retorno: $v0 = 1 se a quantidade estiver certa; 0 caso contrario.
checa_ntokens:
    # Compara a quantidade recebida com a quantidade guardada.
    la   $t0, ntokens
    lw   $t0, 0($t0)
    beq  $t0, $a0, cnt_ok

    # Quantidade errada: mostra a mensagem de comando invalido.
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    la   $a0, msg_invalido
    jal  imprime_str
    lw   $ra, 0($sp)
    addi $sp, $sp, 4

    # Informa ao chamador que a quantidade nao bateu.
    li   $v0, 0
    jr   $ra

cnt_ok:
    li   $v0, 1
    jr   $ra


# obtem_ap
# Entrada: $a0 = string com o numero do AP.
# Retorno: $v0 = endereco do bloco do AP ou zero se invalido.
obtem_ap:
    # Salva $ra porque esta funcao chama outras funcoes.
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # Converte o numero do AP em indice 0..23.
    jal  ap_indice
    bltz $v0, obtem_ap_invalido

    # Converte o indice em endereco de memoria.
    move $a0, $v0
    jal  ap_endereco
    j    obtem_ap_fim

obtem_ap_invalido:
    # O indice negativo significa que o AP nao e valido.
    la   $a0, msg_ap_inval
    jal  imprime_str
    li   $v0, 0

obtem_ap_fim:
    # Restaura o endereco de retorno.
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


# zera_bloco
# Entrada:
#   $a0 = endereco inicial
#   $a1 = numero de bytes que devem ser zerados
zera_bloco:
    # Quando nao restarem bytes, termina.
    beq  $a1, $zero, zera_fim

    # Zera o byte atual.
    sb   $zero, 0($a0)

    # Avanca um byte e reduz a quantidade restante.
    addi $a0, $a0, 1
    addi $a1, $a1, -1
    j    zera_bloco

zera_fim:
    jr   $ra


# limpa_autos
# Entrada: $a0 = endereco-base do apartamento.
# Zera os campos de tipo, quantidade e slots dos automoveis.
limpa_autos:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # Os campos de automoveis comecam no offset OFF_TIPO.
    addi $a0, $a0, OFF_TIPO

    # AUTOS_BYTES cobre ate o final dos 300 bytes do AP.
    li   $a1, AUTOS_BYTES
    jal  zera_bloco

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


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
    lb   $t0, 0($a0)
    beq  $t0, $zero, atoi_erro

atoi_loop:
    lb   $t0, 0($a0)
    beq  $t0, $zero, atoi_fim

    # Limita a entrada a quatro digitos.
    # Isso impede overflow para valores maiores.
    li   $t4, 4
    bge  $t3, $t4, atoi_erro

    # Confere se o caractere esta entre '0' e '9' em ASCII.
    li   $t1, 48
    blt  $t0, $t1, atoi_erro
    li   $t1, 57
    bgt  $t0, $t1, atoi_erro

    # Transforma o caractere ASCII em numero.
    addi $t0, $t0, -48

    # Atualiza o acumulador: numero = numero * 10 + digito.
    mul  $v0, $v0, $t2
    add  $v0, $v0, $t0

    # Avanca para o proximo caractere.
    addi $t3, $t3, 1
    addi $a0, $a0, 1
    j    atoi_loop

atoi_fim:
    jr   $ra

atoi_erro:
    li   $v0, -1
    jr   $ra


# ap_indice
# Converte o numero do apartamento em indice de 0 a 23.
# Exemplo: AP 1102 -> indice 21.
# Retorna -1 se o andar ou o numero do apartamento forem invalidos.
ap_indice:
    # Salva $ra porque esta rotina chama atoi.
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    jal  atoi
    bltz $v0, ap_indice_erro

    # Dividindo por 100:
    #   quociente = andar
    #   resto = numero do AP naquele andar
    li   $t0, 100
    div  $v0, $t0
    mflo $t1                    # andar
    mfhi $t2                    # numero do AP no andar

    # O condominio tem andares de 1 a 12.
    li   $t3, 1
    blt  $t1, $t3, ap_indice_erro
    li   $t3, 12
    bgt  $t1, $t3, ap_indice_erro

    # Cada andar tem AP 1 e AP 2.
    li   $t3, 1
    blt  $t2, $t3, ap_indice_erro
    li   $t3, 2
    bgt  $t2, $t3, ap_indice_erro

    # ?ndice = (andar - 1) * 2 + (AP no andar - 1).
    addi $t1, $t1, -1
    sll  $t1, $t1, 1
    addi $t2, $t2, -1
    add  $v0, $t1, $t2

    # Retorna o indice calculado.
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

ap_indice_erro:
    # Valor negativo sinaliza que o AP nao e valido.
    li   $v0, -1
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


# ap_endereco
# Entrada: $a0 = indice 0..23.
# Retorno: $v0 = endereco inicial do bloco do apartamento.
ap_endereco:
    # Cada AP ocupa AP_SIZE bytes.
    # Endereco = aptos + indice * AP_SIZE.
    li   $t0, AP_SIZE
    mul  $t0, $a0, $t0
    la   $v0, aptos
    add  $v0, $v0, $t0
    jr   $ra


# indice_para_num
# Converte o indice interno para o numero mostrado ao usuario.
# Exemplo: indice 21 -> apartamento 1102.
indice_para_num:
    # Dividir o indice por 2 encontra o andar, comecando em zero.
    srl  $t0, $a0, 1
    addi $t0, $t0, 1
    li   $t1, 100
    mul  $t0, $t0, $t1

    # O ultimo bit indica AP 1 ou AP 2.
    andi $t2, $a0, 1
    addi $t2, $t2, 1
    add  $v0, $t0, $t2
    jr   $ra


# ==========================================================
# ROTINAS DE STRINGS
# ==========================================================

# remove_newline
# Entrada: $a0 = endereco da linha.
# Substitui o primeiro LF (10) ou CR (13) por zero.
remove_newline:
rn_loop:
    lb   $t0, 0($a0)
    beq  $t0, $zero, rn_fim

    li   $t1, 10
    beq  $t0, $t1, rn_achou
    li   $t1, 13
    beq  $t0, $t1, rn_achou

    # Ainda nao chegou ao Enter: examina o proximo byte.
    addi $a0, $a0, 1
    j    rn_loop

rn_achou:
    # Byte zero marca o fim da string.
    sb   $zero, 0($a0)

rn_fim:
    jr   $ra


# trim_direita
# Entrada: $a0 = endereco da string.
# Remove espacos ASCII (32) que estejam no final.
trim_direita:
    move $t0, $a0

td_busca_fim:
    # Avanca ate encontrar o terminador zero.
    lb   $t1, 0($t0)
    beq  $t1, $zero, td_remove
    addi $t0, $t0, 1
    j    td_busca_fim

td_remove:
    # Nao pode recuar antes do primeiro byte.
    beq  $t0, $a0, td_fim

    # Olha o byte anterior ao terminador.
    addi $t0, $t0, -1
    lb   $t1, 0($t0)
    li   $t2, 32

    # Se nao for espaco, a limpeza terminou.
    bne  $t1, $t2, td_fim

    # Troca o espaco final por zero e verifica o anterior.
    sb   $zero, 0($t0)
    j    td_remove

td_fim:
    jr   $ra


# strcmp
# Entradas: $a0 e $a1 apontam para duas strings.
# Retorna zero em $v0 se forem iguais; diferente de zero caso contrario.
strcmp:
strcmp_loop:
    lb   $t0, 0($a0)
    lb   $t1, 0($a1)

    # Um caractere diferente significa que as strings nao sao iguais.
    bne  $t0, $t1, strcmp_diferentes

    # Se ambos chegaram ao zero ao mesmo tempo, sao iguais.
    beq  $t0, $zero, strcmp_iguais

    # Continua comparando o proximo caractere.
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
# Entrada: $a0 = endereco da string.
# Retorna em $v0 a quantidade de caracteres antes do zero.
strlen:
    li   $v0, 0

strlen_loop:
    lb   $t0, 0($a0)
    beq  $t0, $zero, strlen_fim

    # Conta o caractere e avanca para o proximo.
    addi $v0, $v0, 1
    addi $a0, $a0, 1
    j    strlen_loop

strlen_fim:
    jr   $ra


# strcpy
# Entradas:
#   $a0 = endereco de destino
#   $a1 = endereco da string de origem
# Copia tambem o byte zero final.
strcpy:
strcpy_loop:
    lb   $t0, 0($a1)
    sb   $t0, 0($a0)

    # Depois de copiar o zero, a copia terminou.
    beq  $t0, $zero, strcpy_fim

    # Avanca nas duas strings.
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    j    strcpy_loop

strcpy_fim:
    jr   $ra


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
    sw   $a0, 0($a1)
    addi $a1, $a1, 4
    li   $v0, 1

sp_loop:
    lb   $t0, 0($a0)
    beq  $t0, $zero, sp_fim

    # Procura o primeiro byte do separador: espaco ASCII 32.
    li   $t1, 32
    bne  $t0, $t1, sp_proximo

    # Confere se os dois bytes seguintes sao hifens ASCII 45.
    lb   $t2, 1($a0)
    li   $t3, 45
    bne  $t2, $t3, sp_proximo

    lb   $t2, 2($a0)
    bne  $t2, $t3, sp_proximo

    # O vetor comporta no maximo cinco tokens.
    # Valor 6 informa ao chamador que havia opcoes demais.
    li   $t4, 5
    beq  $v0, $t4, sp_excesso

    # Encerra a string atual substituindo o espaco por zero.
    sb   $zero, 0($a0)

    # O novo token comeca depois do espaco e dos dois hifens.
    addi $t5, $a0, 3
    sw   $t5, 0($a1)

    # Prepara o endereco da proxima posicao do vetor.
    addi $a1, $a1, 4

    # Atualiza a contagem e pula o separador ja processado.
    addi $v0, $v0, 1
    addi $a0, $a0, 3
    j    sp_loop

sp_proximo:
    # O byte atual nao iniciou o separador; examina o seguinte.
    addi $a0, $a0, 1
    j    sp_loop

sp_excesso:
    # Retorna seis sem escrever alem das cinco posicoes de tokens.
    li   $v0, 6

sp_fim:
    jr   $ra


# ==========================================================
# COMANDO addMorador
# ==========================================================

# Formato:
# addMorador --<numero do AP> --<nome>
cmd_add_morador:
    # Reserva espaco na pilha e salva os registradores que serao usados.
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)

    # O comando requer tres tokens: nome do comando, AP e nome.
    li   $a0, 3
    jal  checa_ntokens
    beq  $v0, $zero, am_fim

    # Converte a opcao do AP em endereco de memoria.
    la   $t0, tokens
    lw   $a0, 4($t0)
    jal  obtem_ap
    beq  $v0, $zero, am_fim
    move $s0, $v0                # $s0 preserva o endereco-base do AP

    # Confere se o AP ja tem o limite de seis moradores.
    lw   $t0, 0($s0)
    li   $t1, MAX_MORADORES
    bge  $t0, $t1, am_cheio

    # Obtem o endereco do nome digitado, que esta em tokens[2].
    la   $t0, tokens
    lw   $s1, 8($t0)             # $s1 preserva o endereco do nome

    # Nome vazio nao pode ser cadastrado.
    move $a0, $s1
    jal  strlen
    beq  $v0, $zero, am_nome_inv

    # Cada campo comporta 32 bytes, incluindo o terminador.
    # Portanto, o texto pode ter no maximo 31 caracteres.
    li   $t1, NOME_SIZE
    bge  $v0, $t1, am_nome_inv

    # O destino e:
    # base do AP + offset dos nomes + quantidade atual * tamanho do campo.
    lw   $t0, 0($s0)
    li   $t1, NOME_SIZE
    mul  $t1, $t0, $t1
    addi $a0, $s0, OFF_NOMES
    add  $a0, $a0, $t1

    # Copia o nome do buffer para o espaco permanente do AP.
    move $a1, $s1
    jal  strcpy

    # So depois da copia aumenta a quantidade de moradores.
    lw   $t0, 0($s0)
    addi $t0, $t0, 1
    sw   $t0, 0($s0)
    j    am_fim

am_cheio:
    # O apartamento ja atingiu o limite de moradores.
    la   $a0, msg_max_morad
    jal  imprime_str
    j    am_fim

am_nome_inv:
    # O nome esta vazio ou nao cabe no campo reservado.
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
# rmvMorador --<numero do AP> --<nome>
cmd_rmv_morador:
    # Reserva espaco na pilha e salva os registradores usados.
    addi $sp, $sp, -20
    sw   $ra, 16($sp)
    sw   $s0, 12($sp)
    sw   $s1, 8($sp)
    sw   $s2, 4($sp)
    sw   $s3, 0($sp)

    # O comando requer tres tokens: nome do comando, AP e nome.
    li   $a0, 3
    jal  checa_ntokens
    beq  $v0, $zero, rm_fim

    # Converte o numero do AP em endereco de memoria.
    la   $t0, tokens
    lw   $a0, 4($t0)
    jal  obtem_ap
    beq  $v0, $zero, rm_fim
    move $s0, $v0                # $s0 = endereco-base do AP

    # Salva a quantidade atual de moradores e o nome procurado.
    lw   $s1, 0($s0)
    la   $t0, tokens
    lw   $s3, 8($t0)             # $s3 = endereco do nome
    li   $s2, 0                  # $s2 = indice do nome examinado

rm_busca:
    # Se o indice chegou a quantidade, o nome nao foi encontrado.
    beq  $s2, $s1, rm_nao_achou

    # Calcula o endereco do nome no indice atual.
    li   $t0, NOME_SIZE
    mul  $t0, $s2, $t0
    addi $a0, $s0, OFF_NOMES
    add  $a0, $a0, $t0

    # Compara o nome guardado com o nome informado pelo usuario.
    move $a1, $s3
    jal  strcmp
    beq  $v0, $zero, rm_achou

    # Continua procurando no proximo campo de nome.
    addi $s2, $s2, 1
    j    rm_busca

rm_nao_achou:
    # Nenhum morador cadastrado tinha esse nome.
    la   $a0, msg_morad_nao
    jal  imprime_str
    j    rm_fim

rm_achou:
    # Reduz a quantidade: ela passa a ser o ultimo indice ocupado.
    addi $s1, $s1, -1

rm_shift:
    # Se o removido era o ultimo, nao ha nomes para deslocar.
    beq  $s2, $s1, rm_zera

    # Copia o proximo nome para o espaco atual, fechando o buraco.
    li   $t0, NOME_SIZE
    mul  $t0, $s2, $t0
    addi $a0, $s0, OFF_NOMES
    add  $a0, $a0, $t0
    addi $a1, $a0, NOME_SIZE
    jal  strcpy

    # Continua ate chegar ao antigo ultimo nome.
    addi $s2, $s2, 1
    j    rm_shift

rm_zera:
    # Limpa o ultimo campo, que ficou sem uso apos a remocao.
    li   $t0, NOME_SIZE
    mul  $t0, $s1, $t0
    addi $a0, $s0, OFF_NOMES
    add  $a0, $a0, $t0
    li   $a1, NOME_SIZE
    jal  zera_bloco

    # Atualiza o contador de moradores do apartamento.
    sw   $s1, 0($s0)

    # Se ainda ha moradores, os automoveis permanecem cadastrados.
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

# Cadastro simples: addAuto --AP --c/m --modelo --placa
cmd_add_auto:
    addi $sp, $sp, -20
    sw $ra, 16($sp)
    sw $s0, 12($sp)
    sw $s1, 8($sp)
    sw $s2, 4($sp)
    sw $s3, 0($sp)
    li $a0, 5
    jal checa_ntokens
    beq $v0, $zero, aa_fim
    la $t0, tokens
    lw $a0, 4($t0)
    jal obtem_ap
    beq $v0, $zero, aa_fim
    move $s0, $v0
    la $t0, tokens
    lw $a0, 8($t0)
    la $a1, txt_c
    jal strcmp
    beq $v0, $zero, aa_carro
    la $t0, tokens
    lw $a0, 8($t0)
    la $a1, txt_m
    jal strcmp
    bne $v0, $zero, aa_tipo_invalido
    li $s1, 2
    j aa_limite
aa_carro:
    li $s1, 1
aa_limite:
    lw $s2, OFF_QTD($s0)
    beq $s2, $zero, aa_campos
    lw $t0, OFF_TIPO($s0)
    bne $t0, $s1, aa_cheio
    li $t0, 1
    beq $s1, $t0, aa_cheio
    li $t0, 2
    bge $s2, $t0, aa_cheio
aa_campos:
    la $t0, tokens
    lw $a0, 12($t0)
    jal strlen
    beq $v0, $zero, aa_modelo
    li $t0, AUTO_PLACA
    bge $v0, $t0, aa_modelo
    la $t0, tokens
    lw $a0, 16($t0)
    jal strlen
    beq $v0, $zero, aa_placa
    li $t0, PLACA_SIZE
    bge $v0, $t0, aa_placa
    li $t0, AUTO_SIZE
    mul $t0, $s2, $t0
    addi $s3, $s0, OFF_AUTO0
    add $s3, $s3, $t0
    move $a0, $s3
    la $t0, tokens
    lw $a1, 12($t0)
    jal strcpy
    addi $a0, $s3, AUTO_PLACA
    la $t0, tokens
    lw $a1, 16($t0)
    jal strcpy
    addi $s2, $s2, 1
    sw $s2, OFF_QTD($s0)
    sw $s1, OFF_TIPO($s0)
    j aa_fim
aa_tipo_invalido:
    la $a0, msg_tipo_inv
    jal imprime_str
    j aa_fim
aa_cheio:
    la $a0, msg_max_auto
    jal imprime_str
    j aa_fim
aa_modelo:
    la $a0, msg_modelo_inv
    jal imprime_str
    j aa_fim
aa_placa:
    la $a0, msg_placa_inv
    jal imprime_str
aa_fim:
    lw $s3, 0($sp)
    lw $s2, 4($sp)
    lw $s1, 8($sp)
    lw $s0, 12($sp)
    lw $ra, 16($sp)
    addi $sp, $sp, 20
    jr $ra

# Remove pela placa e compacta o segundo slot quando necessario.
cmd_rmv_auto:
    addi $sp, $sp, -20
    sw $ra, 16($sp)
    sw $s0, 12($sp)
    sw $s1, 8($sp)
    sw $s2, 4($sp)
    sw $s3, 0($sp)
    li $a0, 3
    jal checa_ntokens
    beq $v0, $zero, ra_fim
    la $t0, tokens
    lw $a0, 4($t0)
    jal obtem_ap
    beq $v0, $zero, ra_fim
    move $s0, $v0
    lw $s1, OFF_QTD($s0)
    la $t0, tokens
    lw $s3, 8($t0)
    li $s2, 0
ra_busca:
    bge $s2, $s1, ra_nao
    li $t0, AUTO_SIZE
    mul $t0, $s2, $t0
    addi $a0, $s0, OFF_PLACA0
    add $a0, $a0, $t0
    move $a1, $s3
    jal strcmp
    beq $v0, $zero, ra_achou
    addi $s2, $s2, 1
    j ra_busca
ra_nao:
    la $a0, msg_auto_nao
    jal imprime_str
    j ra_fim
ra_achou:
    beq $s2, $zero, ra_primeiro
    addi $a0, $s0, OFF_AUTO1
    addi $a1, $s0, OFF_AUTO0
    li $a2, AUTO_SIZE
ra_move:
    beq $a2, $zero, ra_primeiro
    lb $t0, 0($a0)
    sb $t0, 0($a1)
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    addi $a2, $a2, -1
    j ra_move
ra_primeiro:
    addi $s1, $s1, -1
    li $t0, AUTO_SIZE
    mul $t0, $s1, $t0
    addi $a0, $s0, OFF_AUTO0
    add $a0, $a0, $t0
    li $a1, AUTO_SIZE
    jal zera_bloco
    sw $s1, OFF_QTD($s0)
    bne $s1, $zero, ra_fim
    sw $zero, OFF_TIPO($s0)
ra_fim:
    lw $s3, 0($sp)
    lw $s2, 4($sp)
    lw $s1, 8($sp)
    lw $s0, 12($sp)
    lw $ra, 16($sp)
    addi $sp, $sp, 20
    jr $ra

cmd_limpar_ap:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $a0, 2
    jal checa_ntokens
    beq $v0, $zero, cl_fim
    la $t0, tokens
    lw $a0, 4($t0)
    jal obtem_ap
    beq $v0, $zero, cl_fim
    move $a0, $v0
    li $a1, AP_SIZE
    jal zera_bloco
cl_fim:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

cmd_formatar:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $a0, 1
    jal checa_ntokens
    beq $v0, $zero, cf_fim
    la $a0, aptos
    li $a1, TOTAL_BYTES
    jal zera_bloco
cf_fim:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# Consulta resumida: AP e moradores; autos aparecem quando cadastrados.
cmd_info_ap:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
    li $a0, 2
    jal checa_ntokens
    beq $v0, $zero, ci_fim
    la $t0, tokens
    lw $a0, 4($t0)
    la $a1, txt_all
    jal strcmp
    beq $v0, $zero, ci_todos
    la $t0, tokens
    lw $a0, 4($t0)
    jal ap_indice
    bltz $v0, ci_invalido
    move $s0, $v0
    addi $s1, $v0, 1
    j ci_loop
ci_todos:
    li $s0, 0
    li $s1, NUM_APS
ci_loop:
    bge $s0, $s1, ci_fim
    move $a0, $s0
    jal ap_endereco
    move $s2, $v0
    la $a0, txt_ap
    jal imprime_str
    move $a0, $s0
    jal indice_para_num
    move $a0, $v0
    li $v0, 1
    syscall
    la $a0, txt_nl
    jal imprime_str
    lw $t0, 0($s2)
    beq $t0, $zero, ci_vazio
    la $a0, txt_morad
    jal imprime_str
    li $t1, 0
ci_moradores:
    bge $t1, $t0, ci_autos
    li $t3, NOME_SIZE
    mul $t3, $t1, $t3
    addi $a0, $s2, OFF_NOMES
    add $a0, $a0, $t3
    jal imprime_str
    la $a0, txt_nl
    jal imprime_str
    addi $t1, $t1, 1
    lw $t0, 0($s2)
    j ci_moradores
ci_autos:
    lw $t0, OFF_QTD($s2)
    beq $t0, $zero, ci_proximo
    lw $t1, OFF_TIPO($s2)
    li $t3, 1
    bne $t1, $t3, ci_moto
    la $a0, txt_carro
    j ci_tipo
ci_moto:
    la $a0, txt_moto
ci_tipo:
    jal imprime_str
    li $t1, 0
ci_auto_loop:
    bge $t1, $t0, ci_fim_linha
    beq $t1, $zero, ci_modelo
    la $a0, txt_sep
    jal imprime_str
ci_modelo:
    li $t3, AUTO_SIZE
    mul $t3, $t1, $t3
    addi $a0, $s2, OFF_AUTO0
    add $a0, $a0, $t3
    jal imprime_str
    # A placa fica a AUTO_PLACA bytes depois do inicio do slot.
    la $a0, txt_sep
    jal imprime_str
    addi $a0, $s2, OFF_PLACA0
    add $a0, $a0, $t3
    jal imprime_str
    addi $t1, $t1, 1
    lw $t0, OFF_QTD($s2)
    j ci_auto_loop
ci_fim_linha:
    la $a0, txt_nl
    jal imprime_str
    j ci_proximo
ci_vazio:
    la $a0, txt_vazio
    jal imprime_str
ci_proximo:
    addi $s0, $s0, 1
    j ci_loop
ci_invalido:
    la $a0, msg_ap_inval
    jal imprime_str
ci_fim:
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra

cmd_info_geral:
    addi $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)
    li $a0, 1
    jal checa_ntokens
    beq $v0, $zero, cg_fim
    li $s0, 0
    li $s1, 0
cg_loop:
    li $t0, NUM_APS
    bge $s0, $t0, cg_resultado
    move $a0, $s0
    jal ap_endereco
    lw $t0, 0($v0)
    beq $t0, $zero, cg_proximo
    addi $s1, $s1, 1
cg_proximo:
    addi $s0, $s0, 1
    j cg_loop
cg_resultado:
    # Percentual inteiro de APs ocupados: quantidade * 100 / 24.
    li $t0, 100
    mul $t0, $s1, $t0
    li $t1, NUM_APS
    div $t0, $t1
    mflo $t2
    la $a0, txt_nvazios
    jal imprime_str
    move $a0, $s1
    li $v0, 1
    syscall
    la $a0, txt_pa
    jal imprime_str
    move $a0, $t2
    li $v0, 1
    syscall
    la $a0, txt_pf
    jal imprime_str
    la $a0, txt_nl
    jal imprime_str
    la $a0, txt_vazios
    jal imprime_str
    li $t0, NUM_APS
    subu $a0, $t0, $s1
    li $v0, 1
    syscall
    la $a0, txt_pa
    jal imprime_str
    li $t0, 100
    subu $a0, $t0, $t2
    li $v0, 1
    syscall
    la $a0, txt_pf
    jal imprime_str
cg_fim:
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# Syscall 13/14 le para buffer temporario; so substitui aptos na leitura completa.
carregar_arquivo:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)
    li $v0, 13
    la $a0, arq_nome
    li $a1, 0
    li $a2, 0
    syscall
    bltz $v0, ca_falha
    move $s0, $v0
    li $v0, 14
    move $a0, $s0
    la $a1, buffer_arquivo
    li $a2, TOTAL_BYTES
    syscall
    move $t0, $v0
    li $v0, 16
    move $a0, $s0
    syscall
    li $t1, TOTAL_BYTES
    bne $t0, $t1, ca_falha
    la $a0, aptos
    la $a1, buffer_arquivo
    li $a2, TOTAL_BYTES
ca_copia:
    beq $a2, $zero, ca_ok
    lb $t0, 0($a1)
    sb $t0, 0($a0)
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    addi $a2, $a2, -1
    j ca_copia
ca_ok:
    li $v0, 1
    j ca_fim
ca_falha:
    move $v0, $zero
ca_fim:
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

cmd_salvar:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)
    li $a0, 1
    jal checa_ntokens
    beq $v0, $zero, cs_fim
    li $v0, 13
    la $a0, arq_nome
    li $a1, 1
    li $a2, 0
    syscall
    bltz $v0, cs_erro
    move $s0, $v0
    li $v0, 15
    move $a0, $s0
    la $a1, aptos
    li $a2, TOTAL_BYTES
    syscall
    move $t0, $v0
    li $v0, 16
    move $a0, $s0
    syscall
    li $t1, TOTAL_BYTES
    beq $t0, $t1, cs_fim
cs_erro:
    la $a0, msg_arq_erro
    jal imprime_str
cs_fim:
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

cmd_recarregar:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $a0, 1
    jal checa_ntokens
    beq $v0, $zero, cr_fim
    jal carregar_arquivo
    bne $v0, $zero, cr_fim
    la $a0, msg_arq_erro
    jal imprime_str
cr_fim:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
