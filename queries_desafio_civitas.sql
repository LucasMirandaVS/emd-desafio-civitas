-- Buscando os dados
SELECT * FROM rj-cetrio.desafio.readings_2024_06

-- PASSO 1: EDA
-- Contagem total de registros:
SELECT COUNT(*) AS total_registros
FROM rj-cetrio.desafio.readings_2024_06;

-- Primeiras e últimas entradas para verificar o período coberto pelos dados:
SELECT MIN(datahora) AS primeira_datahora, MAX(datahora) AS ultima_datahora    
FROM rj-cetrio.desafio.readings_2024_06;

-- Contagem de veículos por tipo:
SELECT tipoveiculo, COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY tipoveiculo
ORDER BY contagem DESC;

-- Distribuição das velocidades:
SELECT velocidade, COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY velocidade
ORDER BY velocidade;

-- Velocidade média por tipo de veículo:
SELECT tipoveiculo, AVG(velocidade) AS velocidade_media
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY tipoveiculo
ORDER BY velocidade_media DESC;


-- Número de detecções por radar:
SELECT camera_numero, COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY camera_numero
ORDER BY contagem DESC;


-- Distribuição geográfica das detecções (por radar):
SELECT camera_latitude, camera_longitude, COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY camera_latitude, camera_longitude
ORDER BY contagem DESC;
-- MUITA CAMERA C LAT E LNG ZERADA...

-- Contagem de veículos por empresa de radar:
SELECT empresa, COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY empresa
ORDER BY contagem DESC;


-- Distribuição de registros por data e hora:
SELECT DATE(datahora) AS data, COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY DATE(datahora)
ORDER BY data;


-- PASSO 2: Tentando identificar placas clonadas
-- Identificar placas registradas em locais diferentes ao mesmo tempo:
SELECT placa, COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY placa
HAVING COUNT(DISTINCT CONCAT(camera_latitude, ',', camera_longitude)) > 1;


-- Verificar o tempo entre detecções da mesma placa em diferentes locais:
SELECT a.placa, 
       a.datahora AS datahora_a, 
       a.camera_latitude AS latitude_a, 
       a.camera_longitude AS longitude_a,
       b.datahora AS datahora_b, 
       b.camera_latitude AS latitude_b, 
       b.camera_longitude AS longitude_b,
       TIMESTAMP_DIFF(b.datahora, a.datahora, MINUTE) AS tempo_entre_deteccoes
FROM rj-cetrio.desafio.readings_2024_06 a
JOIN rj-cetrio.desafio.readings_2024_06 b
ON a.placa = b.placa
AND a.datahora < b.datahora
WHERE a.camera_latitude != b.camera_latitude
AND a.camera_longitude != b.camera_longitude
ORDER BY a.placa, a.datahora;

-- Contagem de detecções por placa e localização:
SELECT placa, camera_latitude, camera_longitude, COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY placa, camera_latitude, camera_longitude
ORDER BY contagem DESC;


-- Analisar placas com detecções em intervalos de tempo muito próximos:
SELECT a.placa, a.datahora AS datahora_a, b.datahora AS datahora_b, 
       TIMESTAMP_DIFF(a.datahora, b.datahora, MINUTE) AS tempo_entre_deteccoes
FROM rj-cetrio.desafio.readings_2024_06 a
JOIN rj-cetrio.desafio.readings_2024_06 b
ON a.placa = b.placa
AND a.datahora < b.datahora
WHERE TIMESTAMP_DIFF(a.datahora, b.datahora, MINUTE) between 0 and 5
ORDER BY a.placa, a.datahora;


-- PASSO 3: Deep Dive nas placas clonadas
-- Obter detalhes das placas duplicadas por intervalo de tempo e localização:
SELECT placa, 
       COUNT(*) AS contagem,
       MIN(datahora) AS primeira_ocorrencia, 
       MAX(datahora) AS ultima_ocorrencia
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY placa
HAVING contagem > 1
ORDER BY contagem DESC;


-- Contagem de ocorrências duplicadas por intervalo de tempo (em minutos):
SELECT placa, 
       COUNT(*) AS contagem,
       TIMESTAMP_TRUNC(datahora, MINUTE) AS intervalo_tempo
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY placa, intervalo_tempo
HAVING COUNT(*) > 1
ORDER BY contagem DESC, intervalo_tempo;



-- Verificar detalhes de registros duplicados para uma placa específica:
SELECT TO_HEX(placa) AS placa_hex, 
       datahora, 
       camera_latitude, 
       camera_longitude,
       TIMESTAMP_DIFF(LEAD(datahora) OVER (PARTITION BY TO_HEX(placa) ORDER BY datahora), datahora, SECOND) AS tempo_proximo_registro
FROM rj-cetrio.desafio.readings_2024_06
ORDER BY placa_hex, datahora;


-- Placas capturadas por diferentes empresas ao mesmo tempo:
SELECT a.placa, 
       a.datahora, 
       a.empresa AS empresa_a, 
       b.empresa AS empresa_b
FROM rj-cetrio.desafio.readings_2024_06 a
JOIN rj-cetrio.desafio.readings_2024_06 b
ON a.placa = b.placa
AND a.datahora = b.datahora
AND a.empresa != b.empresa
ORDER BY a.datahora;


-- Analisar ocorrências duplicadas por radar (camera_numero):
SELECT placa, 
       camera_numero, 
       COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY placa, camera_numero
HAVING contagem > 1
ORDER BY contagem DESC;

-- Verificar registros duplicados com informações adicionais:
SELECT a.placa, 
       a.datahora AS datahora_a, 
       a.camera_latitude AS latitude_a, 
       a.camera_longitude AS longitude_a,
       a.empresa AS empresa_a, 
       b.datahora AS datahora_b, 
       b.camera_latitude AS latitude_b, 
       b.camera_longitude AS longitude_b,
       b.empresa AS empresa_b,
       TIMESTAMP_DIFF(b.datahora, a.datahora, MINUTE) AS tempo_entre_deteccoes
FROM rj-cetrio.desafio.readings_2024_06 a
JOIN rj-cetrio.desafio.readings_2024_06 b
ON a.placa = b.placa
AND a.datahora < b.datahora
WHERE a.camera_latitude != b.camera_latitude
AND a.camera_longitude != b.camera_longitude
ORDER BY a.placa, a.datahora;


-- Analisar ocorrências duplicadas por dia:
SELECT placa, 
       DATE(datahora) AS data,
       COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY placa, DATE(datahora)
HAVING contagem > 1
ORDER BY contagem DESC;


-- PASSO 4 IDENTIFICANDO INCONSISTENCIAS
-- Contagem de registros com latitude e longitude zeradas:
SELECT COUNT(*) AS contagem_lat_long_zeradas
FROM rj-cetrio.desafio.readings_2024_06
WHERE camera_latitude = 0 AND camera_longitude = 0;


-- Porcentagem de registros com latitude e longitude zeradas em relação ao total:
SELECT 
    (COUNTIF(camera_latitude = 0 AND camera_longitude = 0) / COUNT(*)) * 100 AS porcentagem_lat_long_zeradas
FROM rj-cetrio.desafio.readings_2024_06;


-- Listar os registros com latitude e longitude zeradas:
SELECT placa, datahora, empresa, tipoveiculo, velocidade, camera_numero, camera_latitude, camera_longitude
FROM rj-cetrio.desafio.readings_2024_06
WHERE camera_latitude = 0 AND camera_longitude = 0
ORDER BY datahora;


-- Contagem de registros com latitude e longitude zeradas por placa:
SELECT TO_HEX(placa) AS placa, COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
WHERE camera_latitude = 0 AND camera_longitude = 0
GROUP BY placa
ORDER BY contagem DESC;


-- Contagem de registros com latitude e longitude zeradas por empresa:
SELECT empresa, COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
WHERE camera_latitude = 0 AND camera_longitude = 0
GROUP BY empresa
ORDER BY contagem DESC;
-- SO TEM UMA EMRPESA COM CAMERAS RUINS


-- Contagem de registros com latitude e longitude zeradas por tipo de veículo:
SELECT tipoveiculo, COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
WHERE camera_latitude = 0 AND camera_longitude = 0
GROUP BY tipoveiculo
ORDER BY contagem DESC;


-- Contagem de registros com latitude e longitude zeradas por data:
SELECT DATE(datahora) AS data, COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
WHERE camera_latitude = 0 AND camera_longitude = 0
GROUP BY DATE(datahora)
ORDER BY data;

-- Analisar a distribuição de velocidades para registros com latitude e longitude zeradas:
SELECT velocidade, COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
WHERE camera_latitude = 0 AND camera_longitude = 0
GROUP BY velocidade
ORDER BY velocidade;



-- Comparar a distribuição de velocidades entre registros com e sem latitude e longitude zeradas:
SELECT 
    CASE 
        WHEN camera_latitude = 0 AND camera_longitude = 0 THEN 'Zerada'
        ELSE 'Normal'
    END AS tipo_localizacao,
    velocidade,
    COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
GROUP BY tipo_localizacao, velocidade
ORDER BY tipo_localizacao, velocidade;



-- Verificando a quantidade de registros com coordenadas zeradas por câmera
SELECT 
    camera_numero,
    COUNT(*) AS quantidade_registros_zerados
FROM 
    rj-cetrio.desafio.readings_2024_06
WHERE 
    camera_latitude = 0 AND camera_longitude = 0
GROUP BY 
    camera_numero
ORDER BY 
    quantidade_registros_zerados DESC;


--- QUERY FINAL
WITH distancia_e_tempo AS (
    SELECT 
        a.placa, 
        a.datahora AS datahora_a, 
        a.camera_latitude AS latitude_a, 
        a.camera_longitude AS longitude_a,
        b.datahora AS datahora_b, 
        b.camera_latitude AS latitude_b, 
        b.camera_longitude AS longitude_b,
        TIMESTAMP_DIFF(b.datahora, a.datahora, SECOND) AS tempo_entre_deteccoes,
        ST_DISTANCE(ST_GEOGPOINT(a.camera_longitude, a.camera_latitude), ST_GEOGPOINT(b.camera_longitude, b.camera_latitude)) AS distancia_m
    FROM 
        rj-cetrio.desafio.readings_2024_06 a
    JOIN 
        rj-cetrio.desafio.readings_2024_06 b
    ON 
        a.placa = b.placa
        AND a.datahora < b.datahora
    WHERE 
        a.camera_latitude != 0 AND a.camera_longitude != 0
        AND b.camera_latitude != 0 AND b.camera_longitude != 0
)

SELECT 
    placa, 
    datahora_a, 
    latitude_a, 
    longitude_a, 
    datahora_b, 
    latitude_b, 
    longitude_b, 
    tempo_entre_deteccoes, 
    distancia_m
FROM 
    distancia_e_tempo
WHERE 
    tempo_entre_deteccoes < 60  -- menos de 1 minuto
    AND distancia_m > 1000       -- Aqui é possivel ajustar a distância conforme necessário (em metros)
ORDER BY 
    placa, datahora_a;
    