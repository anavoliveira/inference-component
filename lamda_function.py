from invoke_endpoints import (
    invoke_endpoint,
    invoke_endpoint_cgi,
    invoke_inference_component,
    invoke_endpoint_pytorch_image,
    check_clarify_config
)
from delete_resources import (
    list_endpoints,
    filter_endpoints_by_name,
    delete_endpoint,
    wait_endpoint_deletion,
    delete_endpoints_by_filter,
    delete_all_resources_by_filter,
    list_resources_by_tags,
    delete_resources_by_tags
)


def lambda_handler(event, context):
    """
    Handler principal da Lambda.
    O event pode conter:
    - action: 'invoke' ou 'delete'
    - endpoint_name: nome do endpoint (para invoke)
    - filter_string: string para filtrar endpoints (para delete, default: 'anvicol')
    - delete_config: booleano para deletar endpoint config (default: True)
    - delete_model: booleano para deletar modelo (default: False)
    """
    # Obter parâmetros do event
    action = event.get('action', 'list_by_tags')  # default: list_by_tags

    if action == 'invoke':
        # Invocar endpoint
        endpoint_name = event.get('endpoint_name', 'iulotus-anvicol-endpoint-scaling-zero-endpoint')
        endpoint_type = event.get('endpoint_type', 'standard')  # 'cgi', 'standard', 'pytorch', 'inference_component'
        inference_component_name = event.get('inference_component_name', 'iulotus-anvicol-endpoint-scaling-zero-ic')

        print(f"Invocando endpoint: {endpoint_name} (type: {endpoint_type})")
        if endpoint_type == 'cgi':
            result = invoke_endpoint_cgi(endpoint_name)
        elif endpoint_type == 'inference_component':
            # Retorna um dict com o resultado da inferência + latência, cold
            # start, copy count/instance count antes e depois, e métricas
            # recentes do CloudWatch - não só o resultado da inferência.
            result = invoke_inference_component(endpoint_name, inference_component_name)
        elif endpoint_type == 'pytorch':
            image_base64 = event.get('image_base64', '')
            result = invoke_endpoint_pytorch_image(endpoint_name, image_base64)
        else:
            result = invoke_endpoint(endpoint_name)

        return {
            'statusCode': 200,
            'body': result
        }

    elif action == 'delete':
        # Deletar endpoints com filtro
        filter_string = event.get('filter_string', 'anvicol')
        delete_config = event.get('delete_config', True)
        delete_model = event.get('delete_model', True)
        region = event.get('region', 'sa-east-1')
        print(f"Deletando endpoints com filtro: '{filter_string}'")
        stats = delete_endpoints_by_filter(
            filter_string=filter_string,
            region_name=region,
            delete_config=delete_config,
            delete_model=delete_model
        )
        return {
            'statusCode': 200,
            'body': stats
        }

    elif action == 'delete_all':
        # Deletar TODOS os recursos (endpoints, configs e models) com filtro
        filter_string = event.get('filter_string', 'anvicol')
        region = event.get('region', 'sa-east-1')
        print(f"Deletando TODOS os recursos com filtro: '{filter_string}'")
        stats = delete_all_resources_by_filter(
            filter_string=filter_string,
            region_name=region
        )
        return {
            'statusCode': 200,
            'body': stats
        }

    elif action == 'list':
        # Listar endpoints
        filter_string = event.get('filter_string', None)
        region = event.get('region', 'sa-east-1')
        all_endpoints = list_endpoints(region)
        if filter_string:
            filtered = filter_endpoints_by_name(all_endpoints, filter_string)
            endpoint_names = [ep['EndpointName'] for ep in filtered]
        else:
            endpoint_names = [ep['EndpointName'] for ep in all_endpoints]
        return {
            'statusCode': 200,
            'body': {
                'total': len(endpoint_names),
                'endpoints': endpoint_names
            }
        }

    elif action == 'list_by_tags':
        # Listar recursos por tags
        target_repos = event.get('target_repos', [
            "itau-pf2-infra-iulotus-testes-automatizados",
            "itau-pf2-infra-tests-built-in-anvicol"
        ])
        target_email = event.get('target_email', 'ana.e.oliveira-silva@itau-unibanco.com.br')
        region = event.get('region', 'sa-east-1')
        print(f"Listando recursos por tags: repos={target_repos}, email={target_email}")
        resources = list_resources_by_tags(
            target_repos=target_repos,
            target_email=target_email,
            region_name=region
        )
        return {
            'statusCode': 200,
            'body': resources
        }

    elif action == 'delete_by_tags':
        # Deletar recursos por tags
        target_repos = event.get('target_repos', [
            "itau-pf2-infra-iulotus-testes-automatizados",
            "itau-pf2-infra-tests-built-in-anvicol"
        ])
        target_email = event.get('target_email', 'ana.e.oliveira-silva@itau-unibanco.com.br')
        region = event.get('region', 'sa-east-1')
        print(f"Deletando recursos por tags: repos={target_repos}, email={target_email}")
        stats = delete_resources_by_tags(
            target_repos=target_repos,
            target_email=target_email,
            region_name=region
        )
        return {
            'statusCode': 200,
            'body': stats
        }

    else:
        return {
            'statusCode': 400,
            'body': f"Action não reconhecida: {action}. Use 'invoke', 'delete', 'delete_all', 'list', 'list_by_tags' ou 'delete_by_tags'."
        }
