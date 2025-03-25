import pyaudio
import numpy as np
from openwakeword.model import Model
import time

# Configurações do microfone - reduzindo CHUNK para evitar overflow
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000
CHUNK = 1280  # Reduzido para um valor menor e potência de 2

# Inicializar PyAudio com tratamento de erros adequado
audio = pyaudio.PyAudio()

# Mostra info dos dispositivos para debug
print("\n=== Dispositivos de Áudio Disponíveis ===")
for i in range(audio.get_device_count()):
    try:
        device_info = audio.get_device_info_by_index(i)
        print(f"Dispositivo {i}: {device_info['name']}")
        print(f"  Canais de entrada: {device_info['maxInputChannels']}")
        print(f"  Taxa de amostragem padrão: {device_info['defaultSampleRate']}")
    except Exception as e:
        print(f"Erro ao obter info do dispositivo {i}: {e}")
print("="*50)

try:
    # Abre o stream com parâmetros mais robustos
    mic_stream = audio.open(
        format=FORMAT, 
        channels=CHANNELS, 
        rate=RATE, 
        input=True, 
        frames_per_buffer=CHUNK,
        input_device_index=None  # Usar dispositivo padrão
    )
    
    # Carregar o modelo personalizado com tratamento de erros
    print("\nCarregando modelo de wake word...")
    model_path = "ma_veee.onnx"
    try:
        owwModel = Model(wakeword_models=[model_path], inference_framework='onnx')
        print("Modelo carregado com sucesso!")
    except Exception as e:
        print(f"Erro ao carregar modelo: {e}")
        raise

    print("\n" + "="*50)
    print("Escutando... Diga a palavra de ativação!")
    print("="*50 + "\n")

    # Período de espera entre leituras para reduzir carga na CPU
    wait_time = 0.01
    
    # Para evitar detecções múltiplas
    last_detection_time = 0
    detection_cooldown = 1.0        # 1 segundo entre detecções
    
    while True:
        try:
            # Parâmetro exception_on_overflow=False evita erros de overflow
            audio_data = np.frombuffer(
                mic_stream.read(CHUNK, exception_on_overflow=False), 
                dtype=np.int16
            )

            # Fazer a predição
            prediction = owwModel.predict(audio_data)

            # Verificar resultados
            for model_name in owwModel.prediction_buffer.keys():
                scores = list(owwModel.prediction_buffer[model_name])
                current_score = scores[-1]
                
                current_time = time.time()
                if current_score > 0.1:  # Limiar de detecção
                    if current_time - last_detection_time > detection_cooldown:
                        print(f"Palavra detectada! (Score: {current_score:.3f})")
                        last_detection_time = current_time
            
            # Pequena pausa para evitar sobrecarga da CPU
            time.sleep(wait_time)
            
        except KeyboardInterrupt:
            print("\nEncerrando por solicitação do usuário...")
            break
        except OSError as e:
            if "Input overflowed" in str(e):
                print("\nAviso: Buffer de entrada sobrecarregado. Continuando...")
                # Pequena pausa para permitir que o buffer se recupere
                time.sleep(0.1)
                continue
            else:
                print(f"\nErro de E/S: {e}")
                break
        except Exception as e:
            print(f"\nErro inesperado: {e}")
            break

except Exception as e:
    print(f"Erro ao inicializar: {e}")

finally:
    # Limpar recursos com verificações adicionais
    print("\nLimpando recursos...")
    try:
        if 'mic_stream' in locals() and mic_stream.is_active():
            mic_stream.stop_stream()
        if 'mic_stream' in locals():
            mic_stream.close()
    except Exception as e:
        print(f"Aviso ao fechar stream: {e}")
    
    try:
        audio.terminate()
    except Exception as e:
        print(f"Aviso ao finalizar PyAudio: {e}")
    
    print("Programa finalizado.")
