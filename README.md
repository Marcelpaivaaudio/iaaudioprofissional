# Protótipo — IA para Análise de Áudio em Tempo Real e Automação de Sistemas de Áudio em Rede

**TCC** — Arquitetura completa em 4 camadas (Figuras 2 e 3):
**Entrada de Áudio → IA (Classificação) → Motor de Decisão → Camada de Integração**

---

## Instalação Rápida (Windows)

**1. Clique duas vezes em `setup.bat`** — ele instala tudo automaticamente.

**2. Ou instale manualmente:**

```bash
# Requer Python 3.10, 3.11 ou 3.12 (com "Add to PATH" marcado)
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

**Se der erro no `sounddevice` no Linux:**
```bash
sudo apt-get install libportaudio2
```

---

## Como Rodar

### Opção 1: Demo no Terminal (rápida)

```bash
venv\Scripts\activate
python src\capture.py              # Lista microfones disponíveis
python src\main_week1.py --device 2 --channel 1   # Classificação ao vivo
```

### Opção 2: Interface Visual (recomendada para apresentação)

```bash
venv\Scripts\activate
streamlit run src\app_streamlit.py
```

Abre no navegador com:
- Seleção de dispositivo/canal na barra lateral
- Classificação ao vivo (categoria + confiança + latência)
- Motor de Decisão (alertas de feedback, sugestão de mute)
- Camada de Integração (comandos simulados para Yamaha, Shure, Allen & Heath, Sennheiser)
- Métricas reais no final da sessão + download CSV

---

## Estrutura do Projeto

```
tcc_audio_ia_app_v2/
├── setup.bat                          # Instalação automática (Windows)
├── requirements.txt                   # Dependências
├── README.md                          # Este arquivo
├── RELATORIO_TECNICO.md               # Relatório completo com dados reais
├── sessao_metrica_*.csv               # Dados exportados de sessões reais
├── sessao_metrica_*_grafico.png       # Gráficos gerados
└── src/
    ├── capture.py                     # Camada 1: Entrada de Áudio
    ├── classifier.py                  # Camada 2: IA/Classificação (YAMNet)
    ├── decision_engine.py             # Camada 3: Motor de Decisão
    ├── main_week1.py                  # Demo terminal (Camadas 1+2)
    ├── app_streamlit.py               # Demo visual completa (4 camadas)
    ├── gerar_grafico_latencia.py      # Gera gráfico do CSV exportado
    └── adapters/                      # Camada 4: Integração
        ├── base_adapter.py            # Interface abstrata (ABC)
        ├── yamaha_adapter.py          # TCP/IP (porta 49280)
        ├── allen_heath_adapter.py     # MIDI sobre TCP/IP (porta 51325)
        ├── sennheiser_adapter.py      # HTTPS/REST (porta 443)
        └── shure_adapter.py           # Command Strings TCP (porta 2202)
```

---

## Sobre o Protótipo

- **Modelo de IA:** YAMNet (521 classes, pré-treinado pelo Google no dataset AudioSet)
- **Hardware utilizado:** Focusrite Scarlett USB Audio (canal 2, 4 entradas)
- **Latência medida:** 19–97ms por bloco (após warmup), 0ms para silêncio
- **Adaptadores:** Simulados (nenhum comando é enviado pela rede)
- **Dados reais:** CSV com 30 blocos de sessão real incluso

---

## Geração de Gráfico (para o TCC)

```bash
python src\gerar_grafico_latencia.py sessao_metrica_20260728_222119.csv
```

Gera um PNG com scatter plot de latência vs. confiança — dados reais para substituir a Figura 1 do documento.
