**Falco Deployment SOP** \
This SOP demonstrates how to build a complete GKE security stack for anomaly detection and to prevent container runtime security threats. We will integrate Falco runtime security engine with Google Cloud Functions and Pub/Sub.

To deploy
1. build the base: `make falco_base && make push_falco_base`     
1. build the daemonSet's image `make && make push`     
1. deploy `kc create -f ./deploy/daemonset.yml`     

*   Kubernetes Falco agents: You need to install Falco in your cluster to collect, directly from the Kubernetes nodes, the runtime security events and detect anomalous behavior.
*   Serverless / Cloud playbooks: A set of Google Cloud Functions that will execute security playbooks (like killing or isolating a suspicious pod) when triggered.

These two pieces will communicate using Google Pub/Sub.

Before describing the complete GKE security stack, let’s learn more about the building blocks that we intend to use.

## **Introducing Falco for GKE security.**

[Falco](https://falco.org/) is an open source project for container security for Cloud Native platforms such as Kubernetes. Originally developed at Sysdig, it is now an independent project [under the CNCF umbrella](https://sysdig.com/blog/falco-cncf-sandbox/).

[Leveraging Falco's open source Linux kernel instrumentation, Falco gains deep insight into system behavior.](https://sysdig.com/blog/sysdig-and-falco-now-powered-by-ebpf/) The rules engine can then detect abnormal activity and runtime security threats in applications, containers, the underlying host, and the container platform itself.

The Falco engine dynamically loads a set of default and user-defined security rules described using YAML files. This would be a token example of a Falco runtime security rule targeting containers:

- rule: Terminal shell in container

  desc: A shell was used as the entrypoint/exec point into a container with an attached terminal.

  condition: >

    spawned_process and container

    and shell_procs and proc.tty != 0

    and container_entrypoint

  output: >

    A shell was spawned in a container with an attached terminal (user=%user.name %container.info

    shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline terminal=%proc.tty)

  priority: NOTICE

  tags: [container, shell]

The rule above will detect and notify any attempt to attach a terminal shell in to a running container. This shouldn’t happen (or at least not in the production, user-facing infrastructure). It is out of scope for this article to fully explain the falco rule format or capabilities, so we are just going to use the default security ruleset. We just wanted to let you know that you can create and customize your own container security rules if you want to.

Also note that Falco is not just using the kernel instrumentation datasource, but can also consume security-related events from other runtime sources, like [the Kubernetes Audit Log](https://sysdig.com/blog/falco-0-13-released-kubernetes-audit-support/). This will be an example of a Falco rule designed to detect unwanted Kubernetes ClusterRole tampering:

- rule: System ClusterRole Modified/Deleted

  desc: Detect any attempt to modify/delete a ClusterRole/Role starting with system

  condition: kevt and (role or clusterrole) and (kmodify or kdelete) and (ka.target.name startswith "system:") and ka.target.name!="system:coredns"

  output: System ClusterRole/Role modified or deleted (user=%ka.user.name role=%ka.target.name ns=%ka.target.namespace action=%ka.verb)

  priority: WARNING

  source: k8s_audit

  tags: [k8s]


## **GKE stack: Falco, FluentD, Pub/Sub and SumoLogic.**

In order to extend Falco, we are going to integrate two Google Cloud technologies as part of our stack: FluentD agent and Google Cloud Pub/Sub. 

&lt;fluentD> description

Asynchronous communication between a set of producers and consumers requires an efficient and reliable messaging middleware. These solutions are commonly known as Publish/Subscribe messaging (PubSub). By using [Google Cloud Pub/Sub](https://cloud.google.com/pubsub/) we can abstract away all the complexities associated with the communication of our two major building blocks.

We can now put everything together using the following diagram:

Listed by alphabetical order:


### 


### **A – GKE cluster and Kubernetes nodes**

This is the Kubernetes cluster that you want to monitor and secure. This is where the entire GKE security workflow starts (detecting a security threat) and ends (performing a remediation action).


### **B – Falco deployment using a DaemonSet**

Falco will be deployed as a Kubernetes DaemonSet, which means that you will have a Falco pod Running in each Kubernetes node. This pod is composed of two containers “C” and “D”.


### **C – Falco Cloud Native runtime security engine**

The Falco security engine that we described above running inside a container. It will keep monitoring the host and container activity and forwarding the triggered security events to container “D”.

Let’s take a look at this security event message generated by Falco:

{  

   "output":"17:10:29.724747835: Notice A shell was spawned in a container with an attached terminal (user=root nginx1 (id=06b29170462e) shell=bash parent=&lt;NA> cmdline=bash  terminal=34816)",

   "priority":"Notice",

   "rule":"Terminal shell in container",

   "time":"2019-03-28T17:10:29.724747835Z",

   "output_fields":{  

      "container.id":"06b29170462e",

      "container.name":"nginx",

      "evt.time":1553793029724747835,

      "proc.cmdline":"bash ",

      "proc.name":"bash",

      "proc.pname":null,

      "proc.tty":34816,

      "user.name":"root"

   }

} \


We have all the relevant pieces of information that we need:



*   The security rule that was fired
*   Affected container (and its ID)
*   Timestamp for the event
*   Trespassing user and process id

These events are then passed to the connector sidecar container “D”.


### **D – FluentD Agent**

Tails, processes the JSON payloads for the security events before sending them to the Google Cloud Pub/Sub queue.


### **E – Google Cloud Pub/Sub message broker**

This middleware piece manages the connection between the Falco event emitters (B) and the serverless function consumers (F).

Thanks to this mediation we can replace any of the two parts separately, event if the other end is not yet ready to send or accept messages and also enables us to plug different event consumers with different purposes in the future, if we want to do so.


### **F – SIEM Alerting and Dashboards**

Sumologic provides the following functionality



*   Forward a Slack notification
*   Drive dashboards
*   … more to come.

These functions are subscribed to a PubSub topic, their operational workflow can be summarized as:



*   The PubSub subscription hook notifies the function(s) whenever there is a new security event waiting in the pipe
*   Every individual function parses the event and decides whether to fire the response depending on the event type and container metadata \



## **How to implement GKE security with Falco.**


### **Creating needed infrastructure on GKE**

In Sysdig we are people obsessed with automation. In this case, creating a Pub/Sub topic is not a big deal, but we crafted a [Terraform](https://sysdig.com/blog/gke-security-using-falco/terraform.io) manifest to automate this task.

First of all, clone the repository:

$ git clone [https://github.com/acme/falco-docker.git](https://github.com/acme/falco-docker.git) \


Next step is to access the deployment directory and choose the google-clouddirectory and just type makefor deploying the Pub/Sub topic.

$ cd kubernetes-response-engine/deployment/google-cloud

$ make

Of course, you will need to specify the Google Cloud project required settings. Our recommendation is to use the [environment variables](https://www.terraform.io/docs/providers/google/provider_reference.html) and with something like [direnv](https://direnv.net/) you can keep the values for further references. If you feel more comfortable using the Google Cloud Console tool, it also will work fine.


### 


### **Installing Falco on GKE**

We will start installing the software living inside the cluster, the Falco DaemonSet.

//TODO: $ kubectl -n team-security create -f ./deploy/k8s/daemonset.yml \
 \
After a few minutes validate the deployment

$ kubectl get pods

NAME                   READY   STATUS    RESTARTS   AGE

falco-1-mwv2j   2/2     Running   1          2m

falco-1-t2prc   2/2     Running   1          2m

alco-1-zldz2   2/2     Running   1          2m

As you can see, there are two containers per pod (READY column). The in-cluster part is ready, now let’s deploy the serverless entities.

Now, we will simulate one of the security incidents spawning an interactive shell in this container:

//TODO write this section \
$ kubectl create -f ./tests/event-generator.yml \
                           

Let’s check the logs produced by the Falco engine:

$ kubectl logs -l role=security -c falco | grep "nginx-falco"

{"output":"16:16:47.908565738: Notice A shell was spawned in a container with an attached terminal (user=root k8s.pod=nginx-falco container=0042056722bb shell=bash parent=&lt;NA> cmdline=bash  terminal=34816)","priority":"Notice","rule":"Terminal shell in container","time":"2019-04-01T16:16:47.908565738Z", "output_fields": {"container.id":"0042056722bb","evt.time":1554135407908565738,"k8s.pod.name":"nginx-falco","proc.cmdline":"bash ","proc.name":"bash","proc.pname":null,"proc.tty":34816,"user.name":"root"}}

Our GKE security pipeline is working and we have full logs for the entire operation!

//TODO write the SumoLogic sections \
 \
Implement dashboard \
Implement Alerts \
Test
