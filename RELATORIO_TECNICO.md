# Relatório Técnico — Protótipo IA para Análise de Áudio em Tempo Real

**Projeto:** TCC — IA para Análise de Áudio em Tempo Real e Automação de Sistemas de Áudio em Rede
**Data:** 28/07/2026
**Máquina de teste:** Windows (Python 3.12), Focusrite Scarlett USB Audio
**Versão do protótipo:** v3 (Semana 3 — Arquitetura completa: 4 camadas)

---

## 1. Resumo Executivo

O protótipo implementa as **4 camadas** descritas nas Figuras 2 e 3 do TCC:

```
Entrada de Áudio → IA (Classificação) → Motor de Decisão → Camada de Integração
  capture.py        classifier.py       decision_engine.py     adapters/
```

- **Camada 1 — Entrada de Áudio:** Captura 16kHz mono float32 do Focusrite (canal 2), leitura bloqueante via PortAudio
- **Camada 2 — IA/Classificação:** YAMNet (521 classes, Google AudioSet) → 7 categorias do TCC + medição de latência
- **Camada 3 — Motor de Decisão:** Regras operacionais (feedback, silêncio prolongado, fala, ruído) → códigos de ação
- **Camada 4 — Integração:** 4 adaptadores simulados (Yamaha, Allen & Heath, Sennheiser, Shure) traduzem ações para protocolos específicos

Duas correções críticas foram aplicadas no hardware:
1. Bug do PortAudio/WASAPI (modo callback com sinal quase nulo)
2. Captura do canal errado do Focusrite (multi-canal)

---

## 2. Ambiente de Execução

### 2.1 Dependências (requirements.txt)

```
sounddevice>=0.4.6
numpy
tensorflow>=2.16
tensorflow-hub>=0.16
scipy
streamlit
setuptools<72
matplotlib
```

**Fixes aplicados:**
- `setuptools<72` — compatibilidade com `tensorflow-hub`
- `matplotlib` — para geração de gráficos de latência

### 2.2 Dispositivos de Áudio Detectados

| Índice | Nome | Canais | Host API |
|--------|------|:-:|:-:|
| 0 | Microsoft Sound Mapper - Input | 2 | MME (0) |
| 1 | Webcam 4 (NDI Webcam Audio) | 2 | MME (0) |
| **2** | **Analogue 1 + 2 (Focusrite USB Audio)** | **4** | **MME (0)** |
| 4 | Line In / Microphone (Waves SoundGrid) | 8 | MME (0) |
| 12 | Analogue 1 + 2 (Focusrite USB Audio) | 4 | DirectSound (1) |
| 14 | Line In / Microphone (Waves SoundGrid) | 8 | DirectSound (1) |
| 22 | Analogue 1 + 2 (Focusrite USB Audio) | 2 | WASAPI (2) |

**Dispositivo utilizado:** Device 2 (Focusrite, MME, 4 canais) — canal 2 (índice 1).

---

## 3. Correções de Hardware Aplicadas

### 3.1 Fix #1 — Bug do PortAudio/WASAPI (modo callback)

**Problema:** `InputStream` com `callback` + `blocksize=16000` retornava RMS ~0.0001 vs. ~0.02 no modo bloqueante (200x de diferença).

| Método | blocksize | RMS | Peak |
|--------|:-:|:-:|:-:|
| `sd.rec()` (bloqueante) | N/A | 0.014926 | 0.088165 |
| `InputStream.read()` (sem blocksize) | - | 0.019047 | 0.097931 |
| `InputStream.read()` (com blocksize) | 16000 | 0.004964 | 0.049347 |
| `InputStream` (callback) | 16000 | 0.000070 | 0.000244 |

**Solução:** Modo bloqueante (`stream.read()`) sem `blocksize`.

### 3.2 Fix #2 — Canal errado do Focusrite

| Canal | RMS | Peak |
|:-:|:-:|:-:|
| 0 (Input 1) | 0.000015 | 0.000061 |
| **1 (Input 2)** | **0.000164** | **0.001007** |
| 2 (Input 3) | 0.000015 | 0.000031 |
| 3 (Input 4) | 0.000015 | 0.000031 |

**Solução:** Parâmetro `--channel` para selecionar canal do dispositivo multi-canal.

---

## 4. Arquitetura Detalhada (4 Camadas)

### 4.1 Camada 1 — Entrada de Áudio (`capture.py`)

- `AudioCapture(sample_rate=16000, block_size=16000, device=None, channel=0)`
- `start()` — Abre `sd.InputStream` com N canais (baseado no device e canal)
- `get_block()` — Lê 16000 samples (1s) em modo bloqueante, extrai canal específico
- `blocks()` — Gerador infinito para iteração
- `list_input_devices()` — Lista dispositivos de entrada

### 4.2 Camada 2 — IA / Classificação (`classifier.py`)

- `AudioClassifier()` — Carrega YAMNet via TensorFlow Hub (~20MB, cacheável)
- `classify(waveform)` → dict:
  - Se RMS < 0.01: retorna "Silêncio" (early return, ~0.001ms)
  - Caso contrário: YAMNet → 521 classes → média temporal → top-3 → mapeamento para categorias TCC
  - Retorna: `categoria`, `confianca`, `top_classes`, `rms`, `latencia_ms`

**Categorias do TCC (mapeamento por keyword):**

| Categoria | Keywords (AudioSet) |
|-----------|-------------------|
| Fala | speech, conversation, narration, monologue |
| Música | music |
| Aplauso | applause, clapping |
| Silêncio | silence |
| Feedback/Ruído agudo | feedback, squeal, hum, static, white noise |
| Ruído | noise, crowd, babble |
| Outro | (qualquer coisa não mapeada) |

### 4.3 Camada 3 — Motor de Decisão (`decision_engine.py`)

- `DecisionEngine(blocos_para_silencio_prolongado=8, confianca_minima_anomalia=0.15)`
- `process(resultado_classificacao)` → `Decisao`:

| Regra | Condição | Resultado | acao_codigo |
|-------|----------|-----------|-------------|
| Feedback agudo | categoria == "Feedback/Ruído agudo" | Alerta imediato | `REDUZIR_GANHO` |
| Silêncio prolongado | ≥ N blocos seguidos de silêncio | Sugere mute | `SUGERIR_MUTE` |
| Fala com baixa confiança | confianca < 0.15 | Anomalia | — |
| Fala normal | confianca ≥ 0.15 | Operação normal | — |
| Música/Aplauso | — | Informativo | — |
| Ruído significativo | confianca ≥ 0.5 | Alerta | `ALERTA_APENAS` |
| Outro | — | Anomalia leve | — |

### 4.4 Camada 4 — Integração Simulada (`adapters/`)

| Adaptador | Fabricante | Protocolo | IP:Porta simulados |
|-----------|-----------|-----------|-------------------|
| `YamahaAdapter` | Yamaha MTX/MRX/XMV | TCP/IP | 192.168.0.10:49280 |
| `AllenHeathAdapter` | Allen & Heath Avantis | MIDI sobre TCP/IP | 192.168.0.20:51325 |
| `SennheiserAdapter` | Sennheiser SSCv2 | HTTPS/REST | 192.168.0.30:443 |
| `ShureAdapter` | Shure ANI22 | Command Strings (TCP) | 192.168.0.40:2202 |

**Exemplo de tradução (SUGERIR_MUTE, canal 1):**

```
Yamaha:        TCP 192.168.0.10:49280 -> SET MUTE CH1 ON
Allen & Heath: MIDI-TCP 192.168.0.20:51325 -> NOTE_ON CH1 (Mute Group A) vel=127
Sennheiser:    POST https://192.168.0.30/api/device/audio/mute {"channel": 1, "mute": true}
Shure:         TCP 192.168.0.40:2202 -> < SET 1 AUDIO_MUTE ON >
```

**Nenhum comando é enviado de verdade** — apenas log simulado.

---

## 5. Interface Visual (Streamlit)

`streamlit run src/app_streamlit.py`

### 5.1 Sidebar (configuração)
- Seleção de dispositivo/canal de áudio
- Duração da demonstração (10–120s)
- Threshold de silêncio (3–20 blocos)
- Seleção de fabricantes ativos (multiselect)
- Canal destino no equipamento (1–32)

### 5.2 Área principal
- **Classificação ao vivo:** categoria, confiança, top-3 YAMNet, latência
- **Motor de Decisão:** estado + alertas/ações
- **Camada de Integração:** comandos simulados por fabricante
- **Log da sessão:** últimas 20 linhas

### 5.3 Métricas quantitativas (pós-sessão)
- Latência média, mínima, máxima, p95
- Distribuição de categorias (blocos)
- Botão de download CSV com todos os dados por bloco

### 5.4 Geração de gráfico (dados reais para o TCC)

```bash
python src/gerar_grafico_latencia.py sessao_metrica_YYYYMMDD_HHMMSS.csv
```

Gera PNG com scatter plot: latência (ms) vs. confiança da classificação — para substituir a Figura 1 (ilustrativa) do TCC por dados efetivamente medidos.

---

## 6. Resultados de Teste (dados reais da sessão 2026-07-28 22:21)

### 6.1 Métricas da sessão (CSV: `sessao_metrica_20260728_222119.csv`)

| Métrica | Valor |
|---------|:-:|
| Blocos processados | 30 |
| Duração | ~30s |
| Latência média | 30.5 ms |
| Latência mín | 0.0 ms (silêncio, early return) |
| Latência máx | 620.7 ms (1ª inferência YAMNet — cold start) |
| Latência pós-warmup | 19–97 ms |

### 6.2 Distribuição de categorias

| Categoria | Blocos | % |
|-----------|:-:|:-:|
| Silêncio | 22 | 73% |
| Fala | 8 | 27% |

### 6.3 Ações do Motor de Decisão

- **SUGERIR_MUTE** disparado 7 vezes (22:21:13–22:21:19) — silêncio prolongado detectado
- Nenhum alerta de feedback/ruído agudo nesta sessão

### 6.4 Latência de inferência medida

| Caminho | Latência observada |
|---------|:-:|
| Silêncio (early return, RMS < 0.01) | ~0.0 ms |
| 1ª inferência YAMNet (cold start) | 620.7 ms |
| Inferências subsequentes (warm) | 19–97 ms |

### 6.5 Faixas de RMS observadas

| Faixa RMS | Classificação |
|:-:|---|
| 0.000 – 0.010 | Silêncio (early return, sem YAMNet) |
| 0.010 – 0.050 | Fala (confiança 0.8–0.98) |
| 0.050 – 0.100 | Fala (sinal moderado) |

---

## 7. Estrutura do Código

```
tcc_audio_ia_app_v2/
├── requirements.txt
├── README.md
├── RELATORIO_TECNICO.md
└── src/
    ├── capture.py              # Camada 1: Entrada de Áudio
    ├── classifier.py           # Camada 2: IA / Classificação (YAMNet)
    ├── decision_engine.py      # Camada 3: Motor de Decisão
    ├── main_week1.py           # Demo terminal (Camadas 1+2)
    ├── app_streamlit.py        # Demo visual completa (4 camadas)
    ├── gerar_grafico_latencia.py  # Gera gráfico de latência do CSV
    └── adapters/               # Camada 4: Integração
        ├── __init__.py
        ├── base_adapter.py     # Interface abstrata (ABC)
        ├── yamaha_adapter.py   # TCP/IP (porta 49280)
        ├── allen_heath_adapter.py  # MIDI sobre TCP/IP (porta 51325)
        ├── sennheiser_adapter.py   # HTTPS/REST (porta 443)
        └── shure_adapter.py    # Command Strings TCP (porta 2202)
```

---

## 8. Comandos para Execução

```bash
# 1. Ativar ambiente virtual
cd C:\Users\Marcel Paiva\Downloads\tcc_audio_ia_app_v2
venv\Scripts\activate

# 2. Listar dispositivos de áudio
python src\capture.py

# 3. Demo terminal (captura + classificação)
python src\main_week1.py --device 2 --channel 1

# 4. Demo visual completa (4 camadas + métricas)
streamlit run src\app_streamlit.py

# 5. Gerar gráfico de latência do CSV exportado
python src\gerar_grafico_latencia.py sessao_metrica_YYYYMMDD_HHMMSS.csv
```

---

## 9. Problemas Conhecidos

1. **YAMNet requer internet na primeira execução** (~20MB). Depois fica em cache.
2. **Mapeamento de categorias por keyword em inglês.** "Mantra", "Chant" → "Outro" (pode ser refinado).
3. **Threshold de silêncio fixo** (RMS < 0.01). Ajustável no código.
4. **Latência YAMNet ~388ms** — aceitável para demo, mas limita taxa de processamento a ~2.5 blocos/s.
5. **Adaptadores são simulados** — nenhum comando é enviado pela rede (demo sem hardware real).

---

## 10. Arquivos Incluídos

| Arquivo | Descrição |
|---------|-----------|
| `requirements.txt` | Dependências (incluindo matplotlib) |
| `README.md` | Documentação atualizada (Semana 3) |
| `sessao_metrica_20260728_222119.csv` | Dados reais da sessão (30 blocos) |
| `sessao_metrica_20260728_222119_grafico.png` | Gráfico latência vs. confiança |
| `src/capture.py` | Camada 1: Entrada de Áudio (corrigido) |
| `src/classifier.py` | Camada 2: IA/Classificação + latência |
| `src/decision_engine.py` | Camada 3: Motor de Decisão |
| `src/main_week1.py` | Demo terminal |
| `src/app_streamlit.py` | Demo visual (4 camadas + métricas + CSV) |
| `src/gerar_grafico_latencia.py` | Gerador de gráfico de latência |
| `src/adapters/` | 4 adaptadores simulados + base abstrata |

---

*Relatório atualizado em 28/07/2026 — Semana 3 (arquitetura completa).*
