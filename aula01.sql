/* aula01.sql: Configura��o do Ambiente
 * Copyright (C) 2016 Daniela Petruzalek
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
 
---------------
-- OBJETIVOS --
---------------
 
/*
  O objetivo deste script � realizar as configura��es necess�rias para preparar
  o ambiente do curso para as pr�ximas aulas.
  
  Pontos chave:
  - Pr�-configurar acessos dos principais usu�rios
  - Entendimento da arquitetura da VM
  - Cria��o do usu�rio CURSO no PDB ORCL.
*/

----------------
-- INTRODU��O --
----------------

/*
  O ambiente da pr�tica est� configurado com um Oracle Database 12c Enterprise
  Edition 12.1.0.2 com as options in-memory e multitenant.
  
  Destacando a import�ncia do multitenant, isto implica que a forma para
  realizar altera��es no banco de dados � um pouco diferente do que est�o
  acostumados com a arquitetura n�o-multitenant (ou single tenant).
  
  O banco de dados que vamos utilizar para as pr�ticas se chama ORCL. Ele
  � um PDB (pluggable database) dentro do container ORCL12C (tamb�m chamado de
  CDB).
  
  Algumas opera��es de altera��o de par�metros ser�o permitidas dentro do PDB,
  por�m outras precisaremos acessar o CDB diretamente. Instru��es apropriadas
  ser�o apresentadas quando formos alterar um ou outro.
  
  Antes de prosseguir, certifique-se que a VM est� conectada na rede em modo
  BRIDGE. Esta configura��o pode ser modificada com a VM ligada (demora alguns
  segundos para entrar em efeito).
*/

-- Primeiro passo: descobrir o IP da m�quina virtual
-- Executar no sistema operacional da VM (abrir um terminal)
> ifconfig enp0s3 | grep inet | awk '{ print $2 }'

----------------------------------------
-- Opcional: configurar arquivo hosts --
----------------------------------------

/*
  Com o IP da VM em m�os, precisamos configurar as conex�es no banco. Para 
  facilitar, voc� pode adicionar um alias para o IP no arquivo 'hosts' do seu 
  sistema operacional. Este passo � inteiramente opcional.
 */
 
-- Windows: %systemroot%\System32\drivers\etc\hosts
-- Linux  : /etc/hosts

-- Exemplo de linha a ser adicionada (troque pelo IP da VM)
192.168.1.23  curso12c

-- Testando na linha de comando do SO do hospedeiro:
ping curso12c

---------------------------
-- Configurando Conex�es --
---------------------------

/*
  O pr�ximo passo � criar os mapeamentos de conex�o no banco de dados. Se voc�
  estiver utilizando o SQL Developer este � um processo simples. Basta adicionar
  uma nova conex�o e informar o IP (ou alias) e os dados abaixo.
  
  Caso voc� prefira utilizar o m�todo pelo Oracle client, dever� adicionar um
  TNSNAMES no seu tnsnames.ora.

  Configurar os seguintes bancos de dados/conex�es:
 
  --- SYSDBA do CDB ---
  usu�rio : sys
  password: oracle
  role    : sysdba
  hostname: ip-da-vm ou alias
  sid     : orcl12c

  --- SYSTEM do CDB ---
  usu�rio : system
  password: oracle
  role    : default
  hostname: ip-da-vm ou alias
  sid     : orcl12c
  
  --- SYSDBA do PDB ---
  usu�rio : sys
  password: oracle
  role    : sysdba
  hostname: ip-da-vm ou alias
  service : orcl
  
  --- SYSTEM do PDB ---
  usu�rio : system
  password: oracle
  role    : default
  hostname: ip-da-vm ou alias
  service : orcl  
*/

------------------------------
-- Cria��o do Usu�rio CURSO --
------------------------------

/*
  A partir deste ponto, conecte-se no banco com o usu�rio SYSTEM do ORCL (PDB).
 */

/*
  Apenas para come�armos a nos acostumar com a id�ia, abaixo apresento dois
  comandos que v�o nos ajudar a navegar entre os pluggable databases:
 */

-- mostra o id do container (pdb ou cdb) atual
SHOW CON_ID
-- mostra o nome do container (pdb ou cdb) atual
SHOW CON_NAME

-- Confira que voc� est� no ORCL (con_id = 3) e vamos adiante

/*
  A primeira tarefa � criarmos um usu�rio "menos" privilegiado para o curso,
  pois n�o � adequado utilizar o usu�rio SYS ou SYSTEM para tarefas que n�o 
  sejam extritamente da al�ada dos mesmos.
  
  O Oracle trata os usu�rios SYS e SYSTEM com caracter�sticas especiais e podem
  existir diferen�as significativas de comportamento entre um processo que roda
  com um destes usu�rios e outro processo comum.
  
  Por este motivo vamos criar um usu�rio com privil�gios de DBA para o restante
  do curso, e usar SYS ou SYSTEM apenas quando necess�rio.
 */
 
/*
  Observa��o:
  -----------
  Por padr�o todos os scripts cont�m uma linha 'DROP' antes de criar qualquer
  objeto. O objetivo � permitir a reproducibilidade dos scripts quando 
  necess�rio. Quando executar pela primeira vez, n�o precisa rodar os comandos
  drop.
 */

DROP USER curso;
CREATE USER curso IDENTIFIED BY curso;
GRANT CONNECT TO curso;
GRANT DBA     TO curso;

/*
  Al�m de criar o usu�rio, vamos adicionar espa�o para os dados no tablespace
  de usu�rios e modificar o nivel de coleta de estat�sticas.
 */

-- Aumenta o espa�o em disco para o tablespace de usu�rios
ALTER TABLESPACE users ADD DATAFILE '/u01/app/oracle/oradata/orcl12c/orcl/users02.dbf' SIZE 1G;

SHOW PARAMETER statistics_level;

-- Ativa coleta de estat�sticas completa
ALTER SYSTEM SET statistics_level=ALL SCOPE=BOTH;

---------------------------------
-- Aumentar a Mem�ria do Banco --
---------------------------------

/*
  Esta etapa � opcional e s� deve ser executada se a quantidade de mem�ria
  dispon�vel para a VM permitir. O objetivo � aumentar a mem�ria do banco
  de 800M (padr�o) para 1G.
 */

/*
  O pr�ximo passo exige acessar o CDB como SYSDBA. Executar os comandos no
  sistema operacional da VM.
 */

-- Executar no sistema operacional da VM:
> sqlplus sys/oracle@//localhost:1521/orcl12c as sysdba

-- Apenas para criar o h�bito
SHOW CON_NAME
SHOW CON_ID

-- Confira: CON_NAME = CDB$ROOT e CON_ID = 1

-- Aumenta mem�ria disponivel para o banco para 1 GB
ALTER SYSTEM SET MEMORY_MAX_TARGET=1G SCOPE=SPFILE;
ALTER SYSTEM SET MEMORY_TARGET=1G SCOPE=SPFILE;
SHUTDOWN IMMEDIATE;
STARTUP;

/* Pronto! o sistema est� preparado. */