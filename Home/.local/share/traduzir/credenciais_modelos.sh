# Credenciais e modelos — único arquivo de configuração do traduzir.bash.
# Ambos os arquivos DEVEM permanecer na mesma pasta.
# Edite este arquivo e proteja as chaves com: chmod 600 credenciais_modelos.sh
# Para consultar identificadores de modelos de API: llm models.
# IMPORTANTE: SUA_CHAVE_* é exemplo e sempre será IGNORADA.

# Pode incluir quantas chaves do mesmo provedor desejar.
# Os identificadores chave 1/N, chave 2/N etc. seguem esta ordem.
# Valores SUA_CHAVE_* e chaves duplicadas são ignorados automaticamente.
TRADUZIR_GEMINI_KEYS=(
    'SUA_CHAVE_GEMINI_1'
    'SUA_CHAVE_GEMINI_2'
    'SUA_CHAVE_GEMINI_3'
    'SUA_CHAVE_GEMINI_4'
    'SUA_CHAVE_GEMINI_5'
)
TRADUZIR_OPENAI_KEYS=(
    'SUA_CHAVE_OPENAI'
)
TRADUZIR_ANTHROPIC_KEYS=(
    'SUA_CHAVE_ANTHROPIC'
)

# CATÁLOGOS POR PROVEDOR — um modelo Gemini nunca é enviado à OpenAI,
# e vice-versa. Configure somente modelos realmente reconhecidos por "llm models".
# Para Gemini, nomes gemini-X.Y-* recebem prefixo "gemini/" automaticamente.
TRADUZIR_MODELOS_GEMINI=(
    'gemini-3.8-flash'  # Exemplo: substitua por ID disponível no llm-gemini.
)
TRADUZIR_MODELOS_OPENAI=(
    'gpt-4o-mini'
)
TRADUZIR_MODELOS_ANTHROPIC=(
    'claude-haiku-4-5'
)
# Para modelos compatíveis com a API OpenAI já configurados no seu CLI llm.
# As chaves usadas serão TRADUZIR_OPENAI_KEYS; endpoints/chaves próprios de
# terceiros necessitam de configuração específica do plugin llm correspondente.
TRADUZIR_MODELOS_OPENAI_COMPATIVEIS=(
    # 'meu-modelo-openai-compativel'
)

# DOCUMENTAÇÃO NATIVA PRIORITÁRIA (GNU/Linux)
# Detecta páginas man COMPLETAS pela própria saída de "man comando | traduzir".
# Se houver versão portuguesa realmente instalada, usa-a ANTES do menu e
# dos tradutores artificiais. A pesquisa não depende do histórico do Bash.
# Nunca reexecuta o comando arbitrário anterior; somente o próprio "man".
# Se não houver documentação localizada, a escolha de tradutor é normal.
# TRADUZIR_NATIVO_MAN=0        # Padrão: 1 (ativado); descomente 0 para desativar
# TRADUZIR_NATIVO_LARGURA=80  # colunas na página man localizada
# Para saídas EXATAS de --help de comandos GNU seguros, tenta primeiro a
# ajuda localizada com gettext (somente se pt_BR.UTF-8 estiver instalado).
# Confere a identidade da saída com o --help inglês antes de substituí-la.
# TRADUZIR_NATIVO_AJUDA=0      # Padrão: 1 (ativado); descomente 0 para desativar
# Debian 13: sudo apt install man-db manpages-pt-br manpages-pt-br-dev
# Nota: catálogos gettext traduzem mensagens na ORIGEM do comando, quando
# executado com locale apropriado; não traduzem stdout já capturado pelo pipe.

# LISTA DE NÃO TRADUZÍVEIS (translate-shell, Apertium e Argos)
# Após escolher um tradutor convencional, o programa pergunta se a lista será usada.
# Em sessões sem TTY, a lista é ativada por padrão nos três tradutores.
TRADUZIR_BLOQUEAR_ASPAS_SEM_CHAVES=1
# Exemplo: em '"conteúdo": "{}"', apenas '"conteúdo"' é protegido pela regra
# de aspas, pois '"{}"' contém chaves ({}).
# Itens literais são preservados exatamente, incluindo maiúsculas/minúsculas.
TRADUZIR_BLOQUEIOS_LITERAIS=(
    'systemd'
    'Wayland'
)
# Expressões regulares Python, cada uma aplicada sem atravessar linhas.
TRADUZIR_BLOQUEIOS_REGEX=(
    # 'ID-[0-9]+'
)
# TRADUZIR_SHELL_BLOQUEIOS_SEM_TTY=1  # 1: com lista em todos os tradutores, 0: sem lista

# Sem TTY (automação), DESCOMENTE para escolher o modo de tradução:
# TRADUZIR_MODO_SEM_TTY=argos  # api, shell, apertium ou argos
# Com terminal, SEMPRE será apresentado o menu de modos.

# Ajustes opcionais (descomente para alterar):
# TRADUZIR_MAX_TENTATIVAS=8  # 3 sequenciais e 5 restantes em paralelo por lotes
# TRADUZIR_SEQUENCIAIS=3
# TRADUZIR_PARALELO=3  # Após 3 erros, chamadas paralelas (máximo por lote)
# TRADUZIR_CACHE=1
# TRADUZIR_DIR="$HOME/traduções"
# TRADUZIR_TRANS_ENGINE=auto

# APERTIUM — tradução offline por pares de idiomas instalados.
# 'auto' utiliza SOMENTE tradução direta inglês→português, dando preferência
# a pt_BR. Se não houver par direto, o terminal pergunta explicitamente se
# deseja usar dois pares via espanhol ou escolher outro mecanismo.
# Sem TTY, não haverá fallback via espanhol automático: retorna um erro claro.
# Se não houver modo direto pt_BR, pode selecionar português europeu.
# Confira os modos REALMENTE instalados com: apertium -l
# Atenção: instalar somente o pacote "apertium" não instala todos os pares.
# TRADUZIR_APERTIUM_MODOS=auto
# TRADUZIR_APERTIUM_MODOS='eng-spa,es-pt_BR'  # Opt-in EXPLÍCITO à rota via espanhol, inclusive sem TTY; confirme com apertium -l
# TRADUZIR_APERTIUM_DATADIR=   # Diretório opcional de dados compilados (-d)

# ARGOS TRANSLATE — tradução neural offline, sem Ollama/LLM.
# Necessita de argostranslate e de um pacote de idiomas previamente instalado.
# Veja: argospm update; argospm search --from-lang en --to-lang pb
# Exemplo de ID oficial: translate-en_pb. Confira antes com argospm search.
# TRADUZIR_ARGOS_ORIGEM=en
# TRADUZIR_ARGOS_DESTINO=pb  # pb = português brasileiro; pt = português europeu.
# TRADUZIR_OFFLINE_TIMEOUT=90
# TRADUZIR_OFFLINE_WORKERS=1
# Execução preferencial do Argos via biblioteca Python (carrega modelo só uma vez);
# se acessível somente como CLI, usa argos-translate (mais lento por linha).

# BLINDAGEM RÍGIDA — aplicada aos três tradutores convencionais com bloqueios.
# Protege a grafia exata de comandos e blocos de configuração (como "input ..."),
# enums "enabled|disabled", opções/flags, caminhos, URLs, referências man(5),
# placeholders como <identifier>, variáveis, ANSI, formatos %s e números.
# Também descobre identificadores em linhas de sintaxe de manuais e os preserva
# quando reaparecem na explicação. Nada disso usa um terceiro arquivo.
TRADUZIR_BLOQUEAR_ESTRUTURA=1  # 1: regras estruturais/terminologia, 0: desativa
TRADUZIR_BLOQUEAR_NUMEROS=1    # 1: preserva números, medidas e códigos
TRADUZIR_VALIDAR_ESTRUTURA=1   # 1: rejeita tradução se linhas/colunas mudarem
# Bloqueios literais acima: adicione comandos/nomes de software particulares.
# Regex Python acima: acrescente padrões personalizados sem atravessar linhas.
# "Sem bloqueios" no menu dos tradutores desliga esta camada avançada.
