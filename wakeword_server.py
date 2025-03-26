import pyaudio
import numpy as np
from openwakeword.model import Model
import time
import asyncio
import websockets
import json
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configurações do microfone
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000
CHUNK = 1024

class WakeWordDetector:
    def __init__(self, model_path="ma_veee.onnx", threshold=0.1, port=5678):
        self.audio = pyaudio.PyAudio()
        self.model_path = model_path
        self.threshold = threshold
        self.port = port
        self.clients = set()
        self.is_running = False
        self.detection_cooldown = 1.0  # 1 segundo entre detecções
        self.last_detection_time = 0

    async def register(self, websocket):
        self.clients.add(websocket)
        logger.info(f"Cliente conectado. Total: {len(self.clients)}")
        try:
            await websocket.wait_closed()
        finally:
            self.clients.remove(websocket)
            logger.info(f"Cliente desconectado. Total: {len(self.clients)}")

    async def notify_clients(self, message):
        if not self.clients:
            return
        
        # Envia a mensagem para todos os clientes conectados
        await asyncio.gather(
            *[client.send(json.dumps(message)) for client in self.clients],
            return_exceptions=True
        )
        
    async def run_detection(self):
        # Carregar o modelo
        try:
            logger.info(f"Carregando modelo de wake word: {self.model_path}")
            self.model = Model(wakeword_models=[self.model_path], inference_framework='onnx')
            logger.info("Modelo carregado com sucesso!")
        except Exception as e:
            logger.error(f"Erro ao carregar modelo: {e}")
            return
        
        # Abrir stream de áudio
        try:
            self.mic_stream = self.audio.open(
                format=FORMAT, 
                channels=CHANNELS, 
                rate=RATE, 
                input=True, 
                frames_per_buffer=CHUNK,
                input_device_index=None
            )
            logger.info("Stream de áudio inicializado")
        except Exception as e:
            logger.error(f"Erro ao inicializar microfone: {e}")
            return
        
        self.is_running = True
        logger.info("Iniciando detecção de wake word...")
        
        while self.is_running:
            try:
                # Ler dados do microfone
                audio_data = np.frombuffer(
                    self.mic_stream.read(CHUNK, exception_on_overflow=False), 
                    dtype=np.int16
                )
                
                # Fazer a predição
                prediction = self.model.predict(audio_data)
                
                # Verificar resultados
                for model_name in self.model.prediction_buffer.keys():
                    scores = list(self.model.prediction_buffer[model_name])
                    current_score = scores[-1]
                    
                    current_time = time.time()
                    if current_score > self.threshold:
                        if current_time - self.last_detection_time > self.detection_cooldown:
                            logger.info(f"Wake word detectada! (Score: {current_score:.3f})")
                            self.last_detection_time = current_time
                            
                            # Notificar os clientes da detecção
                            await self.notify_clients({
                                "event": "wakeword_detected",
                                "score": float(current_score),
                                "timestamp": current_time
                            })
                
                # Pequena pausa para evitar alta utilização da CPU
                await asyncio.sleep(0.01)
                
            except asyncio.CancelledError:
                logger.info("Detecção cancelada")
                break
            except Exception as e:
                logger.error(f"Erro durante detecção: {e}")
                await asyncio.sleep(0.1)  # Pausa maior em caso de erro
        
        # Limpar recursos
        try:
            if hasattr(self, 'mic_stream'):
                self.mic_stream.stop_stream()
                self.mic_stream.close()
            if hasattr(self, 'audio'):
                self.audio.terminate()
            logger.info("Recursos de áudio liberados")
        except Exception as e:
            logger.error(f"Erro ao limpar recursos: {e}")
    
    async def start_server(self):
        detection_task = asyncio.create_task(self.run_detection())
        
        async with websockets.serve(self.register, "localhost", self.port):
            logger.info(f"Servidor WebSocket iniciado em ws://localhost:{self.port}")
            try:
                await asyncio.Future()  # Executa indefinidamente
            except asyncio.CancelledError:
                logger.info("Servidor interrompido")
            finally:
                self.is_running = False
                detection_task.cancel()
                await asyncio.gather(detection_task, return_exceptions=True)

if __name__ == "__main__":
    detector = WakeWordDetector()
    
    try:
        asyncio.run(detector.start_server())
    except KeyboardInterrupt:
        logger.info("Programa encerrado pelo usuário")
