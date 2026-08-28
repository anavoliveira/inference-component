import time
import json
from datetime import datetime, timedelta, timezone

import boto3

REGION = "sa-east-1"


def invoke_endpoint(endpoint_name):
    """
    Invoca um endpoint SageMaker com um payload simples de features.

    Args:
        endpoint_name: Nome do endpoint SageMaker
    Returns:
        Resultado da inferência
    """
    client = boto3.client("sagemaker-runtime", endpoint_url=f"https://runtime.sagemaker.{REGION}.amazonaws.com")

    features = [0.942, 0.679, 0.685, 0.772, 0.688]
    payload = json.dumps({"data": {"features": features}})
    print("#####################################################")
    print(payload)
    print("#####################################################")
    response = client.invoke_endpoint(
        EndpointName=endpoint_name,
        ContentType="application/jsonlines",
        Body=payload
    )
    result = response["Body"].read().decode()
    print(result)
    return result


def get_inference_component_state(inference_component_name):
    """
    Estado atual do Inference Component: status, cópias rodando agora
    (CurrentCopyCount) e cópias desejadas (DesiredCopyCount) - é isso que
    diz se escalou pra zero ou para 1, 2... cópias.
    """
    client = boto3.client("sagemaker", region_name=REGION)
    resp = client.describe_inference_component(InferenceComponentName=inference_component_name)
    runtime_config = resp.get("RuntimeConfig", {})
    return {
        "Status": resp.get("InferenceComponentStatus"),
        "CurrentCopyCount": runtime_config.get("CurrentCopyCount"),
        "DesiredCopyCount": runtime_config.get("DesiredCopyCount"),
        "FailureReason": resp.get("FailureReason"),
    }


def get_endpoint_instance_state(endpoint_name):
    """
    Quantas instâncias o endpoint tem agora (CurrentInstanceCount /
    DesiredInstanceCount por variant) - complementa get_inference_component_state:
    o ManagedInstanceScaling do endpoint e o DesiredCopyCount do inference
    component são duas dimensões de escala independentes.
    """
    client = boto3.client("sagemaker", region_name=REGION)
    resp = client.describe_endpoint(EndpointName=endpoint_name)
    variants = resp.get("ProductionVariants", [])
    return {
        "EndpointStatus": resp.get("EndpointStatus"),
        "Variants": [
            {
                "VariantName": v.get("VariantName"),
                "CurrentInstanceCount": v.get("CurrentInstanceCount"),
                "DesiredInstanceCount": v.get("DesiredInstanceCount"),
            }
            for v in variants
        ],
    }


def get_recent_cloudwatch_metrics(endpoint_name, inference_component_name, lookback_minutes=15):
    """
    Últimos datapoints publicados no CloudWatch (namespace AWS/SageMaker) para
    o Inference Component: ModelLatency/OverheadLatency (microssegundos),
    Invocations e erros. Pode vir vazio se a métrica ainda não foi publicada -
    o CloudWatch tem alguns minutos de atraso, isso não é bug.
    """
    cw = boto3.client("cloudwatch", region_name=REGION)
    end = datetime.now(timezone.utc)
    start = end - timedelta(minutes=lookback_minutes)
    dimensions = [
        {"Name": "EndpointName", "Value": endpoint_name},
        {"Name": "InferenceComponentName", "Value": inference_component_name},
    ]

    metrics = {}
    for metric_name, stat in [
        ("ModelLatency", "Average"),
        ("OverheadLatency", "Average"),
        ("Invocations", "Sum"),
        ("Invocation4XXErrors", "Sum"),
        ("Invocation5XXErrors", "Sum"),
    ]:
        try:
            resp = cw.get_metric_statistics(
                Namespace="AWS/SageMaker",
                MetricName=metric_name,
                Dimensions=dimensions,
                StartTime=start,
                EndTime=end,
                Period=60,
                Statistics=[stat],
            )
            datapoints = sorted(resp.get("Datapoints", []), key=lambda d: d["Timestamp"])
            metrics[metric_name] = {
                "latest": datapoints[-1][stat] if datapoints else None,
                "datapoint_count": len(datapoints),
            }
        except Exception as exc:
            metrics[metric_name] = {"error": str(exc)}
    return metrics


def invoke_inference_component(endpoint_name, inference_component_name, features=None):
    """
    Invoca um Inference Component medindo latência ponta-a-ponta, cold start
    e estado de escala antes/depois da chamada.

    Args:
        endpoint_name: Nome do endpoint SageMaker
        inference_component_name: Nome do Inference Component
        features: lista de features (opcional, usa um payload de exemplo por padrão)
    Returns:
        dict com o resultado da inferência e as métricas de observabilidade
        (latência, cold start, copy count antes/depois, métricas do CloudWatch)
    """
    runtime_client = boto3.client("sagemaker-runtime", endpoint_url=f"https://runtime.sagemaker.{REGION}.amazonaws.com")

    # Estado ANTES da chamada - é o que permite saber se a chamada provavelmente
    # disparou um cold start (0 cópias rodando quando a chamada começou).
    state_before = get_inference_component_state(inference_component_name)
    endpoint_state_before = get_endpoint_instance_state(endpoint_name)
    was_scaled_to_zero = state_before.get("CurrentCopyCount") == 0

    features = features or [0.942, 0.679, 0.685, 0.772, 0.688]
    payload = json.dumps({"data": {"features": features}})

    print("#####################################################")
    print(f"Estado ANTES da chamada (IC): {state_before}")
    print(f"Estado ANTES da chamada (Endpoint): {endpoint_state_before}")
    print(payload)
    print("#####################################################")

    start_time = time.perf_counter()
    error = None
    result = None
    try:
        response = runtime_client.invoke_endpoint(
            InferenceComponentName=inference_component_name,
            EndpointName=endpoint_name,
            ContentType="application/jsonlines",
            Body=payload,
        )
        result = response["Body"].read().decode()
    except Exception as exc:
        error = str(exc)
    elapsed_ms = (time.perf_counter() - start_time) * 1000

    # Estado DEPOIS - confirma pra quantas cópias/instâncias escalou em
    # resposta a essa chamada (a resposta em si já espera o provisionamento
    # terminar quando parte de zero, então o "depois" já reflete isso).
    state_after = get_inference_component_state(inference_component_name)
    endpoint_state_after = get_endpoint_instance_state(endpoint_name)

    # Heurística de cold start: só é possível ter havido cold start se tinha
    # 0 cópias antes da chamada. O threshold separa uma chamada "quente"
    # (tipicamente dezenas/centenas de ms) de uma que teve que esperar o
    # provisionamento de uma cópia nova (tipicamente dezenas de segundos a
    # poucos minutos, incluindo o boot da instância se ela também estava em 0).
    COLD_START_THRESHOLD_MS = 5000
    likely_cold_start = was_scaled_to_zero and elapsed_ms > COLD_START_THRESHOLD_MS

    cloudwatch_metrics = get_recent_cloudwatch_metrics(endpoint_name, inference_component_name)

    report = {
        "result": result,
        "error": error,
        "latency_ms_client_measured": round(elapsed_ms, 2),
        "was_scaled_to_zero_before_call": was_scaled_to_zero,
        "likely_cold_start": likely_cold_start,
        "inference_component": {
            "before": state_before,
            "after": state_after,
        },
        "endpoint_instances": {
            "before": endpoint_state_before["Variants"],
            "after": endpoint_state_after["Variants"],
        },
        "cloudwatch_recent_metrics": cloudwatch_metrics,
    }

    print("#####################################################")
    print("RELATORIO DE INVOCACAO")
    print(json.dumps(report, indent=2, default=str))
    print("#####################################################")

    return report


def invoke_endpoint_cgi(endpoint_name):
    """
    Invoca um endpoint SageMaker CGI com payload específico.

    Args:
        endpoint_name: Nome do endpoint SageMaker
    Returns:
        Resultado da inferência
    """
    client = boto3.client("sagemaker-runtime", endpoint_url=f"https://runtime.sagemaker.{REGION}.amazonaws.com")

    # Criar um dicionário com os nomes das colunas esperadas
    payload = json.dumps({
        "segmento": "PERSONNALITE",
        "estado": "SP",
        "valor_imovel": 500000.0,
        "entrada_cliente": "SUPER APP",
        "valor_emprestimo": 300000.0,
        "fl_mudanca_entrada": 0,
        "juros_normalizado": 0.75,
        "qtd_propostas": 1,
        "perc_dif_imovel": 1.0,
        "perc_dif_juros": 1.0,
        "perc_dif_solicitado_cliente": 1.0,
        "perc_dif_emprestimo": 1.0,
        "perc_emprestimo_imovel": 0.6,
        "max_safras": 1,
        "Hierarquia - grupo": "1 - Metrópole",  # <- H MAIÚSCULO
        "tempo_primeira_interacao": 0,
        "flag_estado_corrigido": "informação correta",
        "qtd_recusas": 0,
        "fl_diferenca_estado": 1
    })
    print("#####################################################")
    print(payload)
    print("#####################################################")
    response = client.invoke_endpoint(
        EndpointName=endpoint_name,
        ContentType="application/jsonlines",
        Body=payload
    )
    result = response["Body"].read().decode()
    print(result)
    return result


def invoke_endpoint_pytorch_image(endpoint_name, image_base64):
    """
    Invoca o endpoint SageMaker PyTorch para classificação de imagens.

    Args:
        endpoint_name: Nome do endpoint SageMaker
        image_base64: String base64 da imagem
    Returns:
        Resultado da inferência com a classificação e probabilidades
    """
    client = boto3.client("sagemaker-runtime", endpoint_url=f"https://runtime.sagemaker.{REGION}.amazonaws.com")
    # Montar payload no formato esperado pelo endpoint
    payload = {
        "image": image_base64,
        "parameters": {
            "return_probabilities": True,
            "confidence_threshold": 0.5
        }
    }
    payload_json = json.dumps(payload)
    print("#####################################################")
    print(f"Invocando endpoint: {endpoint_name}")
    print(f"Payload size: {len(payload_json)} bytes")
    print(f"Image base64 length: {len(image_base64)} chars")
    print("#####################################################")
    response = client.invoke_endpoint(
        EndpointName=endpoint_name,
        ContentType="application/json",
        Body=payload_json
    )
    result = response["Body"].read().decode()
    print(result)
    return result


def check_clarify_config(endpoint_name):
    """
    Verifica a configuração do Clarify/DataCapture para um endpoint.

    Args:
        endpoint_name: Nome do endpoint SageMaker
    Returns:
        Configuração de DataCapture do endpoint
    """
    sagemaker_client = boto3.client("sagemaker", region_name=REGION)
    # Obter detalhes do endpoint
    response = sagemaker_client.describe_endpoint(EndpointName=endpoint_name)
    endpoint_config_name = response.get("EndpointConfigName")
    print(f"EndpointConfigName: {endpoint_config_name}")
    # Obter detalhes do EndpointConfig
    endpoint_config = sagemaker_client.describe_endpoint_config(EndpointConfigName=endpoint_config_name)
    print(endpoint_config)
    # Verificar DataCaptureConfig
    data_capture_config = endpoint_config.get("DataCaptureConfig")
    if data_capture_config and data_capture_config.get("EnableCapture"):
        print("DataCapture is enabled.")
        print(data_capture_config)
    else:
        print("DataCapture is not enabled.")
    return data_capture_config
