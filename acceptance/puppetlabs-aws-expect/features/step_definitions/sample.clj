(use '[clojure.java.shell :only [sh]])
(use '[amazonica.aws.ec2])
(use '[amazonica.aws.elasticloadbalancing])

(def region {:endpoint "sa-east-1"})

(defn uuid [] (str (java.util.UUID/randomUUID)))

(defn in?
  "true if seq contains elm"
  [seq elm]
  (some #(= elm %) seq))

(defn running? [instance] (= "running" (:name (:state instance))))

(defn pending? [instance] (= "pending" (:name (:state instance))))

(defn running-or-pending? [instance]
  (or
    (running? instance)
    (pending? instance)))

(defn get-groups [] (:security-groups
  (describe-security-groups region)))

(defn get-group-names [] (map :group-name (get-groups)))

(defn get-loadbalancers [] (:load-balancer-descriptions
  (describe-load-balancers region)))

(defn get-loadbalancer-names [] (map :load-balancer-name (get-loadbalancers)))

(defn get-instances [] (flatten
  (map :instances
    (:reservations (describe-instances region)))))

(defn get-live-instances [] (filter running-or-pending? (get-instances)))

(defn get-live-instance-names [] (map :value
  (filter #(= (:key %) "Name") (flatten (map :tags (get-live-instances))))))


(Given #"^we namespace our resources with a unique identifier" []
  (def identifier uuid))

(Then #"^we should not find the resources in AWS$" []
  (def instances (get-live-instance-names))
  (def groups (get-group-names))
  (def loadbalancers (get-loadbalancer-names))
  (assert (not (in? instances "test-1")))
  (assert (not (in? groups "test-sg")))
  (assert (not (in? loadbalancers "test-lb"))))

(Then #"^we should find the created resources in AWS$" []
  (def instances (get-live-instance-names))
  (def groups (get-group-names))
  (def loadbalancers (get-loadbalancer-names))
  (assert (in? instances "test-1"))
  (assert (in? groups "test-sg"))
  (assert (in? loadbalancers "test-lb")))

(When #"^we run puppet with '([a-z]+\.pp)'$" [manifest]
  (def command (sh "./run-puppet.sh" manifest))
  (assert (= 0 (:exit command))))

