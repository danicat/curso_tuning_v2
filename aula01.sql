/* aula01.sql: Configuração do Ambiente
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
  O objetivo deste script é realizar as configurações necessárias para preparar
  o ambiente do curso para as próximas aulas.
  
  Pontos chave:
  - Pré-configurar acessos dos principais usuários
  - Entendimento da arquitetura da VM
  - Criação do usuário CURSO no PDB ORCL.
*/

----------------
-- INTRODUÇÃO --
----------------

/*
  O ambiente da prática está configurado com um Oracle Database 12c Enterprise
  Edition 12.1.0.2 com as options in-memory e multitenant.
  
  Destacando a importância do multitenant, isto implica que a forma para
  realizar alterações no banco de dados é um pouco diferente do que estão
  acostumados com a arquitetura não-multitenant (ou single tenant).
  
  O banco de dados que vamos utilizar para as práticas se chama ORCL. Ele
  é um PDB (pluggable database) dentro do container ORCL12C (também chamado de
  CDB).
  
  Algumas operações de alteração de parâmetros serão permitidas dentro do PDB,
  porém outras precisaremos acessar o CDB diretamente. Instruções apropriadas
  serão apresentadas quando formos alterar um ou outro.
  
  Antes de prosseguir, certifique-se que a VM está conectada na rede em modo
  BRIDGE. Esta configuração pode ser modificada com a VM ligada (demora alguns
  segundos para entrar em efeito).
*/

-- Primeiro passo: descobrir o IP da máquina virtual
-- Executar no sistema operacional da VM (abrir um terminal)
> ifconfig enp0s3 | grep inet | awk '{ print $2 }'

----------------------------------------
-- Opcional: configurar arquivo hosts --
----------------------------------------

/*
  Com o IP da VM em mãos, precisamos configurar as conexões no banco. Para 
  facilitar, você pode adicionar um alias para o IP no arquivo 'hosts' do seu 
  sistema operacional. Este passo é inteiramente opcional.
 */
 
-- Windows: %systemroot%\System32\drivers\etc\hosts
-- Linux  : /etc/hosts

-- Exemplo de linha a ser adicionada (troque pelo IP da VM)
192.168.1.23  curso12c

-- Testando na linha de comando do SO do hospedeiro:
ping curso12c

---------------------------
-- Configurando Conexões --
---------------------------

/*
  O próximo passo é criar os mapeamentos de conexão no banco de dados. Se você
  estiver utilizando o SQL Developer este é um processo simples. Basta adicionar
  uma nova conexão e informar o IP (ou alias) e os dados abaixo.
  
  Caso você prefira utilizar o método pelo Oracle client, deverá adicionar um
  TNSNAMES no seu tnsnames.ora.

  Configurar os seguintes bancos de dados/conexões:
 
  --- SYSDBA do CDB ---
  usuário : sys
  password: oracle
  role    : sysdba
  hostname: ip-da-vm ou alias
  sid     : orcl12c

  --- SYSTEM do CDB ---
  usuário : system
  password: oracle
  role    : default
  hostname: ip-da-vm ou alias
  sid     : orcl12c
  
  --- SYSDBA do PDB ---
  usuário : sys
  password: oracle
  role    : sysdba
  hostname: ip-da-vm ou alias
  service : orcl
  
  --- SYSTEM do PDB ---
  usuário : system
  password: oracle
  role    : default
  hostname: ip-da-vm ou alias
  service : orcl  
*/

------------------------------
-- Criação do Usuário CURSO --
------------------------------

/*
  A partir deste ponto, conecte-se no banco com o usuário SYSTEM do ORCL (PDB).
 */

/*
  Apenas para começarmos a nos acostumar com a idéia, abaixo apresento dois
  comandos que vão nos ajudar a navegar entre os pluggable databases:
 */

-- mostra o id do container (pdb ou cdb) atual
SHOW CON_ID
-- mostra o nome do container (pdb ou cdb) atual
SHOW CON_NAME

-- Confira que você está no ORCL (con_id = 3) e vamos adiante

/*
  A primeira tarefa é criarmos um usuário "menos" privilegiado para o curso,
  pois não é adequado utilizar o usuário SYS ou SYSTEM para tarefas que não 
  sejam extritamente da alçada dos mesmos.
  
  O Oracle trata os usuários SYS e SYSTEM com características especiais e podem
  existir diferenças significativas de comportamento entre um processo que roda
  com um destes usuários e outro processo comum.
  
  Por este motivo vamos criar um usuário com privilégios de DBA para o restante
  do curso, e usar SYS ou SYSTEM apenas quando necessário.
 */
 
/*
  Observação:
  -----------
  Por padrão todos os scripts contém uma linha 'DROP' antes de criar qualquer
  objeto. O objetivo é permitir a reproducibilidade dos scripts quando 
  necessário. Quando executar pela primeira vez, não precisa rodar os comandos
  drop.
 */

DROP USER curso;
CREATE USER curso IDENTIFIED BY curso;
GRANT CONNECT TO curso;
GRANT DBA     TO curso;

/*
  Além de criar o usuário, vamos adicionar espaço para os dados no tablespace
  de usuários e modificar o nivel de coleta de estatísticas.
 */

-- Aumenta o espaço em disco para o tablespace de usuários
ALTER TABLESPACE users ADD DATAFILE '/u01/app/oracle/oradata/orcl12c/orcl/users02.dbf' SIZE 1G;

SHOW PARAMETER statistics_level;

-- Ativa coleta de estatísticas completa
ALTER SYSTEM SET statistics_level=ALL SCOPE=BOTH;

---------------------------------
-- Aumentar a Memória do Banco --
---------------------------------

/*
  Esta etapa é opcional e só deve ser executada se a quantidade de memória
  disponível para a VM permitir. O objetivo é aumentar a memória do banco
  de 800M (padrão) para 1G.
 */

/*
  O próximo passo exige acessar o CDB como SYSDBA. Executar os comandos no
  sistema operacional da VM.
 */

-- Executar no sistema operacional da VM:
> sqlplus sys/oracle@//localhost:1521/orcl12c as sysdba

-- Apenas para criar o hábito
SHOW CON_NAME
SHOW CON_ID

-- Confira: CON_NAME = CDB$ROOT e CON_ID = 1

-- Aumenta memória disponivel para o banco para 1 GB
ALTER SYSTEM SET MEMORY_MAX_TARGET=1G SCOPE=SPFILE;
ALTER SYSTEM SET MEMORY_TARGET=1G SCOPE=SPFILE;
SHUTDOWN IMMEDIATE;
STARTUP;

/* Pronto! o sistema está preparado. */