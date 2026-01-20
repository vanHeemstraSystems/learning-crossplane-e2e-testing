# learning-crossplane-e2e-testing
Learning Crossplane End-to-End Testing

# Choose Your Own Adventure: The Treacherous Trek to Production

From the moment of their inception as source code on the developer's laptop, our hero knows that they are destined for great things. They long to be a real, running application, living in production, serving end users! But the epic journey to production is an arduous one, filled with cascading choices - choices concerning app design, testing, security, container image building, deployment strategy, and observability, to name a few. And who knows what other unseen forces lurk in the shadows! One wrong step could be catastrophic.

## Pitch

It is up to us, the audience, to guide our hero; and to help them grow from source code to container image, to their final form as a running application in production. In this "Choose Your Own Adventure"-style journey, Whitney and Viktor will present a linear view of all of the choices that an anthropomorphized application must make as they try to find their way to the fabled land of production. Throughout the trek, the audience will vote to choose which path our hero application will take. Can we navigate CNCF projects and avoid pitfalls and dead-ends to get our application to production?

Join us if you dare!  This is not for the faint of heart!

## Rules

* Non-CNCF projects lead to a dead end ☠

## The Adventure!

The best place to start the adventure is the beginning. Perform the [setup](manuscript/setup/dev.md) steps and, from there, start the first chapter by going to [Build Container Image In Dev Environments](manuscript/build-container-image/README.md). As an alternative, you can use graph below to navigate through the adventure.

Almost all items in the graphs contain a link if you prefer to jump straight into a specific part of the adventure. If you do so, please note that the steps work only if one start from the beginning of any of the chapters (e.g., Development, Production, etc.).

*For reasons I cannot explain, the links do not work if they are not opened in a separate tab.*

== MERMAID GRAPHS GO HERE ==

More ... (See https://github.com/vanHeemstraSystems/cncf-demohttps://github.com/vanHeemstraSystems/cncf-demo)

## Episodes

### Development

| Name | Guests | Date | Link |
| --- | --- | --- | --- |
| Build Container Image | Cora Iberkleid - Carvel kbld<br />Ryan Moran - Buildpacks<br />Anders Björklund - Lima | Wednesday, February 8, 2023 | [story](manuscript/build-container-image/README.md) |
| Store Container Image in a Registry | Vadim Bauer - Harbor<br />Allen Sun - Dragonfly<br />| Tuesday, February 14, 2023 | [story](manuscript/registry/README.md) |
| Define and Deploy the App to Dev | Andrew Block - Helm<br />Scott Rosenberg - Carvel ytt<br />Eli Polonsky - cdk8s<br />Thomas Vitale - Kustomize<br /> | Tuesday, February 21, 2023 | [story](manuscript/define-deploy-dev/README.md) |
| Use HTTPS | Ashley Davis - cert-manager<br /> | Tuesday, February 28, 2023 | [story](manuscript/https/README.md) |
| Set Up PostgreSQL DB in the Dev Environment | Dan Magnum - Crossplane<br />Andrew Block - Helm<br /> | Tuesday, March 7, 2023 | [story](manuscript/db/README.md) |
| Manage DB Schema | Marc Campbell - SchemaHero<br />Robert Reeves - Liquibase<br /> | Tuesday, March 14, 2023 | [story](manuscript/db-schema/README.md) |
| Develop the App | Nick Powell - Telepresence<br />Carl Montanari - DevSpace<br />Elson Yuen - Devfile<br /> | Tuesday, March 21, 2023 | [story](manuscript/develop/README.md) |
| Chapter 1 Finale! | Just Whitney and Viktor! | Tuesday, March 28, 2023 |  |

### Production

| Name | Guests | Date | Link |
| --- | --- | --- | --- |
| Provision a Production Cluster | Ramon Ramirez-Linan - Crossplane<br />Richard Case - Cluster API | Tuesday, July 18, 2023 | [story](manuscript/cluster/README.md) |
| Configure Synchronization with GitOps | Kingdon Barrett - Flux<br />Christian Hernandez - Argo CD<br />Scott Rosenberg - Carvel kapp-controller | Tuesday, July 25, 2023 | [story](manuscript/gitops/README.md) |
| Implement Ingress | Sunjay Bhatia - Contour with Envoy<br />Ricardo Katz - ingress-nginx<br />Alice Wasko - Emissary-ingress with Envoy | Tuesday, August 1, 2023 | [story](manuscript/ingress/README.md) |
| Chapter 2 Finale! (Including [Deploy The App To Production](manuscript/app/README.md) & [Database Implementation](manuscript/db-production/README.md)) | Whitney and Viktor! | Tuesday, August 8, 2023 | [story](manuscript/app/README.md) |

### Security

| Name | Guests | Date | Link |
| --- | --- | --- | --- |
| Admission Controller Policies | Jim Bugwadia - Kyverno<br />Rita Zhang - Open Policy Agent (OPA) with Gatekeeper<br />Kevin Sonney - Cloud Custodian<br />Flavio Castelli - Kubewarden<br />Tim Bannister - Kubernetes Validating Admission Policy | Tuesday, January 9, 2024 | [story](manuscript/policies/README.md) |
| Runtime Policies | Barun Acharya - KubeArmor<br />Thomas Labarussias - Falco | Tuesday, January 16, 2024 | [story](manuscript/runtime-policies/README.md) |
| Secrets Management | Gergely Brautigam - External Secrets Operator (ESO)<br />Anish Ramasekar - Secrets Store CSI Driver (SSCSID)<br />Saeid Bostandoust - Teller<br />Marcus Noble - Secrets OPerationS (SOPS) | Tuesday, January 23, 2024 | [story](manuscript/secrets/README.md) |
| Mutual TLS and Network Policies | Marino Wijay - Istio<br />Flynn - Linkerd <br />Nick Young - Cilium<br />Charly Molter - Kuma<br />Michael Chenetz - Network Service Mesh | Tuesday, January 30, 2024 | [story](manuscript/mtls/README.md) |
| Kubernetes Scanning | Oshrat Nir - Kubescape<br />Jamie Smith - Snyk | Tuesday, February 6, 2024 | [story](manuscript/scanning/README.md) |
| Signing Artifacts | Milind Gokarn - Notary<br />Hector Fernandez - Sigstore<br />Gert Drapers - Open Policy Containers | Tuesday, February 13, 2024 | [story](manuscript/signing/README.md) |
| Generating Workload Identity | Frederick Kautz - SPIFFE<br />Daniel Feldman - SPIRE<br />Abhijeet Vaidya - Athenz | Tuesday, February 20, 2024 | [story](manuscript/workload-identity/README.md) |
| Authenticating Users | Maksim Nabokikh - Dex<br />Alexander Schwartz - Keycloak | Tuesday, February 27, 2024 | [story](manuscript/user-authentication/README.md) |
| Authorizing Access | Gerry Gebel - Hexa<br />Saim Safdar - Paralus<br />Raghd Hamzeh - OpenFGA  | Tuesday, March 5, 2024 | [story](manuscript/access/README.md) |
| Miscellaneous | Suraj Deshmukh - Confidential Containers<br />Rachid Zarouali - ContainerSSH | Tuesday, March 12, 2024 | [story](manuscript/security-misc/README.md) |
| Chapter 3 Finale! | Whitney and Viktor! | Tuesday, March 19, 2024 |  |

### Observability

| Name | Guests | Date | Link |
| --- | --- | --- | --- |
| Dashboards | Marc Boorshtein - Kubernetes Dashboard<br /> René Dudfield - Headlamp<br /> Lee Calcote - Meshery | September 3, 2024 | [story](manuscript/dashboards/README.md) |
| Episode Postponed! | Guests are busy with PromCon | September 10, 2024 | N/A |
| Open Standards | Austin Parker - OpenTelemetry<br /> Richard "RichiH" Hartmann - Prometheus | September 17, 2024 | [story](manuscript/exposition-formats/README.md) |
| Metrics | Iris Dyrmishi - Prometheus<br /> Saswata Mukherjee - Thanos<br /> Friedrich Gonzalez - Cortex | September 24, 2024 | [story](manuscript/metrics/README.md) |
| Traces | Jonah Kowall - Jaeger<br /> Andriy Redko - Zipkin | October 1, 2024 | [story](manuscript/tracing/README.md) |
| Data Pipelines | Eduardo Silva Pereira - Fluent Bit<br /> Juraci Paixão Kröhling - OTel Collector<br /> Sandor Guba - Logging Operator | October 8, 2024 | [story](manuscript/data-pipelines/README.md) |
| Service Mesh | Nick Young - Cilium<br /> Lin Sun - Istio<br /> William Morgan - Linkerd<br /> Marcin Skalski - Kuma | October 29, 2024 | [story](manuscript/service-mesh/README.md) |
| Progressive Delivery | Christian Hernandez - Argo Rollouts<br /> Sanskar Jaiswal - Flagger | October 15, 2024 | [story](manuscript/progressive-delivery/README.md) |
| Cloud Cost | Matt Ray - OpenCost<br /> Yasmin Rajabi - StormForge<br /> Phil Andrews - CAST AI | October 22, 2024 | TBD |
| Miscellaneous | Kaiyi Liu - Kepler<br /> Jose Blanquicet - Inspektor Gadget<br /> Ronald Petty - K8sGPT<br /> Augustin Husson - Perses<br /> Dom Delnano - Pixie | November 5, 2024 | TBD |
| Chapter 4 Finale! | Whitney and Viktor! | November 22, 2024 |  |

### Internal Developer Platform (IDP)

| Name | Guests | Date | Link |
| --- | --- | --- | --- |
API and State Management| Tobias Kässer - Crossplane<br />Fog Dong - KubeVela<br />Abby Bangser - Kratix | January 28, 2025 | [story](manuscript/api/README.md) |
| Policies and State Synchronization (Review) | Whitney and Viktor - Kyverno<br />Whitney and Viktor - Argo CD | February 4, 2025 | stories: [policies](manuscript/policies-idp/README.md), [state](manuscript/gitops-idp/README.md) |
| One-Shot Actions | Christian Hernandez - Argo Workflows<br />Vincent Demeester - Tekton<br />Matteo Bianchi - GitHub Actions | February 11, 2025 | [story](manuscript/workflows/README.md) |
| Graphical User Interface (GUI) | Scott Rosenberg - Backstage<br />Roadie<br />Sébastien Blanc - Port | February 18, 2025 | [story](manuscript/gui/README.md) |
| Specialized Templating | Sarah Christoff - Porter<br /> Khanh Tran - PipeCD<br />Will Tsai - Radius<br />Aleksei Igrychev - werf<br />Ben Meier - Score | February 25, 2025 | TODO: |
| Miscellaneous | Mauricio Salatino - Dapr<br />Forest Chen - KusionStack<br />Jonathan Norris - OpenFeature | March 4, 2025 | TODO: |
| Chapter 5 Finale! | Whitney and Viktor! | March 25, 2025 |  |

## The Format

* Recap of the decisions made in the app's journey so far (<=5 min.)
* Recap of the technology that was chosen from last week's episode (<=5 min.)
* Implement said technology (<=5 min.)
* Intro current episode: why is this step necessary? (<=5 min.)
* Introduce guests
* Each case presented in <= 5 min.
* Audience questions
* Call for voting
* Closing case presentations (20 sec.)
