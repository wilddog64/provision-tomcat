# Controller Lookup Plugins

The zero-downtime candidate workflow verifies the temporary Tomcat instance from the controller (Kitchen host) before promoting it. To avoid routing those checks through WinRM, we added two custom lookup plugins that run entirely on the controller.

## `controller_port`

**Purpose:** Poll a TCP port from the controller.

**Parameters:**

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `host` | Yes | — | Controller-visible hostname or IP to probe |
| `port` | Yes | — | TCP port to probe |
| `timeout` | No | `5` | Seconds to wait for the TCP handshake |

**Return:**

```yaml
- host: 127.0.0.1
  port: 9080
  timeout: 5.0
  reachable: true
  error: null
```

**Usage:**

```yaml
- name: Wait for candidate port from controller
  ansible.builtin.set_fact:
    candidate_port_check: >-
      {{ lookup('controller_port', host=tomcat_candidate_delegate_host,
                                   port=tomcat_candidate_delegate_port,
                                   timeout=tomcat_candidate_controller_delay) }}
  register: controller_port_result
  until: controller_port_result.ansible_facts.candidate_port_check.reachable | bool
  retries: 24
  delay: 5
```

## `controller_http`

**Purpose:** Execute an HTTP request from the controller and ensure the response code matches the expected list (defaults to `[200, 404]`).

**Parameters:**

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `url` | No | — | Full URL to hit. If omitted, `host`, `port`, `scheme`, and `path` are combined |
| `host` | No* | — | Hostname/IP (required if `url` omitted) |
| `port` | No* | — | Port (required if `url` omitted) |
| `scheme` | No | `http` | Scheme when constructing a URL from host/port |
| `path` | No | `/` | Path appended when constructing a URL |
| `method` | No | `GET` | HTTP method |
| `timeout` | No | `10` | Seconds to wait for the response |
| `allowed_status` | No | `[200, 404]` | Status codes that count as success |
| `validate_certs` | No | `True` | Whether to validate TLS certificates |

**Return:**

```yaml
- url: http://127.0.0.1:9080/
  status_code: 200
  ok: true
  body: "...Tomcat default page..."
  error: null
```

**Usage:**

```yaml
- name: Verify candidate HTTP response from controller
  ansible.builtin.set_fact:
    candidate_http_check: >-
      {{ lookup('controller_http',
                host=tomcat_candidate_delegate_host,
                port=tomcat_candidate_delegate_port,
                timeout=30,
                allowed_status=tomcat_candidate_delegate_status_codes) }}
  register: controller_http_result
  failed_when: not controller_http_result.ansible_facts.candidate_http_check.ok | bool
```

## When to use them

These lookups are plugged into `tasks/verify-candidate-controller.yml`, which runs during the candidate workflow when `tomcat_candidate_delegate` or `tomcat_candidate_enabled` is set. They ensure the controller can:

1. Establish a TCP connection to the candidate service on port 9080 (or whatever override you set).
2. Receive a 200/404 HTTP response before we consider the candidate ready for promotion.

Because the checks run locally on the controller, they avoid WinRM-specific issues (`ConvertFrom-Json` errors) and more closely mirror how an external load balancer or health-checking system would monitor the new service.
