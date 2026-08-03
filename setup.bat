@echo off
chcp 65001 >nul
echo ============================================
echo   TCC - IA para Analise de Audio em Tempo Real
echo   Instalacao automatica (Windows)
echo ============================================
echo.

echo [1/4] Verificando Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo ERRO: Python nao encontrado!
    echo Baixe em: https://www.python.org/downloads/
    echo IMPORTANTE: marque "Add Python to PATH" durante a instalacao.
    pause
    exit /b 1
)
python --version
echo.

echo [2/4] Criando ambiente virtual...
if exist venv (
    echo Ambiente virtual ja existe. Recriando...
    rmdir /s /q venv
)
python -m venv venv
if errorlevel 1 (
    echo ERRO ao criar ambiente virtual.
    pause
    exit /b 1
)
echo Ambiente virtual criado.
echo.

echo [3/4] Ativando ambiente e instalando dependencias...
call venv\Scripts\activate.bat
pip install --upgrade pip >nul 2>&1
pip install -r requirements.txt
if errorlevel 1 (
    echo ERRO ao instalar dependencias.
    pause
    exit /b 1
)
echo.
echo Dependencias instaladas:
echo   - sounddevice (captura de audio)
echo   - tensorflow + tensorflow-hub (modelo YAMNet)
echo   - streamlit (interface visual)
echo   - matplotlib (graficos)
echo.

echo [4/4] Verificando instalacao...
python -c "import sounddevice; import tensorflow; import streamlit; print('Todas as dependencias OK!')"
if errorlevel 1 (
    echo ERRO: alguma dependencia falhou.
    pause
    exit /b 1
)
echo.

echo ============================================
echo   Instalacao concluida!
echo ============================================
echo.
echo Para rodar a demo no terminal:
echo   venv\Scripts\activate
echo   python src\main_week1.py --device 2 --channel 1
echo.
echo Para rodar a interface visual (Streamlit):
echo   venv\Scripts\activate
echo   streamlit run src\app_streamlit.py
echo.
echo Para listar dispositivos de audio:
echo   python src\capture.py
echo.
pause
