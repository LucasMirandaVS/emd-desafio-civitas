# Desafio CIVITAS - EMD

Esta documentação destina-se a detalhar o passo a passo da resolução do desafio CIVITAS. O arquivo .sql com todas as queries utilizadas também encontra-se neste repositório.

## 1. Análise Exploratória de Dados

Como primeiro passo, realizei uma análise exploratória para entender o tamanho da tabela, os tipos de dados registrados e algumas estatísticas descritivas. 

### Descrição da Tabela

| Coluna           | Tipo       | Descrição                                 |
|------------------|------------|-------------------------------------------|
| datahora         | TIMESTAMP  | Data e hora da detecção do radar          |
| datahora_captura | TIMESTAMP  | Data e hora do recebimento dos dados      |
| placa            | BYTES      | Placa do veículo capturado                |
| empresa          | BYTES      | Empresa do radar                          |
| tipoveiculo      | BYTES      | Tipo do veículo                           |
| velocidade       | INTEGER    | Velocidade do veículo                     |
| camera_numero    | BYTES      | Número identificador do radar             |
| camera_latitude  | FLOAT      | Latitude do radar                         |
| camera_longitude | FLOAT      | Longitude do radar                        |

Dentre as informações observadas, destacam-se:
* Total de entradas na tabela: 36.358.536 registros.
* Tipos de dados ausentes: Identificados 1.816.325 valores nulos na coluna datahora_captura.
* Estatísticas de velocidades anômalas: Foram analisados 2.057 casos de velocidades consideradas anômalas (maiores que 200 ou menores que 0).
* Duplicidade de placas: Observados 140.112 casos em que a mesma placa foi detectada no mesmo momento, indicando possíveis problemas de duplicação de dados.

### 1.1 Inconsistências Detectadas
Durante a análise foram identificadas algumas inconsistências significativas nos dados. Investigando a distribuição geográfica das detecções por radar, foi possível observar um número elevado de registros com coordenadas de latitude e longitude iguais a zero, indicando possíveis falhas nas câmeras de monitoramento.

Contando o número de observações com latitude e longitude zeradas por câmera:

![e7e317dc-f419-4778-92dd-e37028f645af](https://github.com/LucasMirandaVS/emd-desafio-civitas/assets/77032413/322c1d26-f5b2-4bde-8d47-dc326b921563)

Além disso,  ao analisar algumas das coordenadas registradas também pude observar que algumas destas estavam fora do esperado para o território do município do Rio de Janeiro, incluindo até registros no meio do mar. Isso sugere que algumas das câmeras podem estar com problemas na geolocalização.

### 1.2  Analisando as Câmeras de Radar
Ao explorar detalhadamente as câmeras de radar, observou-se que uma delas capturou um número substancialmente maior de veículos em comparação com todas as outras no conjunto de dados. Esta câmera também é uma das que mais apresentou coordenadas de latitude e longitude zeradas, o que pode afetar a precisão geográfica dos registros.

Por fim, vale destacar que os registros com latitude e longitude zerados são provenientes das câmeras da mesma empresa, aqui identificada como "HiVFr51Ixg==".

A query utilizada para identificar os registros zerados por empresa:
```
SELECT empresa,
 COUNT(*) AS contagem
FROM rj-cetrio.desafio.readings_2024_06
WHERE camera_latitude = 0 AND camera_longitude = 0
GROUP BY empresa
ORDER BY contagem DESC;
```

## 2. Identificando as Placas Clonadas

Para construir a query, foram adotadas as seguintes premissas fundamentais:

* Cada placa de veículo é única e não pode ser capturada simultaneamente por múltiplas câmeras.
  
* Não é plausível que uma mesma placa seja detectada por câmeras posicionadas em locais muito distantes entre si.

A query final ficou no seguinte formato:

```
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
```
Para identificar potenciais placas clonadas, a query construída realiza o seguinte processo:

1. Calcula a diferença de tempo em segundos entre as detecções da mesma placa.
2. Utiliza a função ST_DISTANCE para calcular a distância geográfica entre as detecções em metros.
3. Filtra os resultados para exibir apenas as detecções que ocorreram em menos de 1 minuto e onde a distância entre elas é superior a 1000 metros.
4. Ordena os resultados por placa e datahora para facilitar a análise temporal e espacial das detecções.
   
Essa abordagem possibilita identificar padrões que sugerem potenciais casos de clonagem de placas, utilizando como base as premissas definidas: Proximidade temporal e geográfica das detecções registradas pelas câmeras. O resultado finaç da query nos dá as seguintes informações finais:
* placa: A placa do veículo detectado.

* datahora_a: A data e hora da primeira detecção

* latitude_a: A latitude da câmera na primeira detecção

* longitude_a: A longitude da câmera na primeira detecção.

* datahora_b: A data e hora da segunda detecção.

* latitude_b: A latitude da câmera na segunda detecção.

* longitude_b: A longitude da câmera na segunda detecção.

* tempo_entre_deteccoes: O tempo entre as duas detecções, medido em segundos.

* distancia_m: A distância geográfica entre os dois pontos de detecção, medida em metros.

