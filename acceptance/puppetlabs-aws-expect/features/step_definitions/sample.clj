(use '[clojure.string :only (join split)])
(use '[clojure.java.shell :only [sh]])
(use '[amazonica.aws.ec2])
(use '[amazonica.aws.elasticloadbalancing])
(require '[com.brainbot.iniconfig :as iniconfig])

(def region {:endpoint "sa-east-1"})

(defn uuid [] (str (java.util.UUID/randomUUID)))

(defn get-hostname []
  (.getHostName (java.net.InetAddress/getLocalHost)))

(defn get-short-hostname [] (first (split (get-hostname) #"\.")))

(defn get-environment-id [] (or
  (System/getenv "BUILD_DISPLAY_NAME") (System/getenv "USER")))

; on Jenkins, name resources with a pretty build identifier
; otherwise, name instances via local environment info
; for the sake of preventing name collisions
(defn get-suffix [] (clojure.string/replace
  (join "" [(get-environment-id) "@" (get-short-hostname)])
  "'"
  ""))

; some resources have DNS rules, so simplify suffix
(defn get-dns-suffix [] (clojure.string/replace
  (get-suffix) #"[^\\dA-Za-z-]" ""))

(defn in?
  "true if seq contains elm"
  [seq elm]
  (some #(= elm %) seq))

(defn contains-all?
  "true if seq1 contains all items in seq2"
  [seq1 seq2]
  (every? #(in? seq2 %) seq1))

(defn has-suffixed-elements?
  "true if any seq item ends in given suffix "
  [seq suffix]
  (some #(.endsWith % suffix) seq))

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

(def config-file-path (join ""
  ["/tmp/aws-resources-" (get-environment-id) ".ini"]))

(defn get-config-file [] (iniconfig/read-ini config-file-path))

(defn get-config-file-section [ini-section] (
  get (get-config-file) ini-section))

(def get-expected-manifest-resources (memoize get-config-file-section))

(defn get-expected-instance-names [] (split
  (get (get-expected-manifest-resources "resources") "instances")
  #","))

(defn get-expected-loadbalancer-names [] (split
  (get (get-expected-manifest-resources "resources") "loadbalancers")
  #","))

(defn get-expected-group-names [] (split
  (get (get-expected-manifest-resources "resources") "securitygroups")
  #","))

(defn parse-int [s]
   (Integer. (re-find  #"\d+" s )))

(Given #"^we namespace our resources with a unique identifier" []
  (def identifier uuid))

(Then #"^we should not find suffixed resources in AWS$" []
  (def instances (get-live-instance-names))
  (def groups (get-group-names))
  (def loadbalancers (get-loadbalancer-names))
  (def suffix (get-suffix))
  (def dns-suffix (get-dns-suffix))
  (assert (not (has-suffixed-elements? instances suffix)))
  (assert (not (has-suffixed-elements? groups suffix)))
  (assert (not (has-suffixed-elements? loadbalancers dns-suffix))))

(Then #"^we should not find the resources in AWS$" []
  (def instances (get-live-instance-names))
  (def expected-instances (get-expected-instance-names))
  (def groups (get-group-names))
  (def expected-groups (get-expected-group-names))
  (def loadbalancers (get-loadbalancer-names))
  (def expected-loadbalancers (get-expected-loadbalancer-names))
  (assert (not (contains-all? expected-instances instances)))
  (assert (not (contains-all? expected-groups groups)))
  (assert (not (contains-all? expected-loadbalancers loadbalancers))))

(Then #"^we should find the created resources in AWS$" []
  (def instances (get-live-instance-names))
  (def expected-instances (get-expected-instance-names))
  (def groups (get-group-names))
  (def expected-groups (get-expected-group-names))
  (def loadbalancers (get-loadbalancer-names))
  (def expected-loadbalancers (get-expected-loadbalancer-names))
  (assert (contains-all? expected-instances instances))
  (assert (contains-all? expected-groups groups))
  (assert (contains-all? expected-loadbalancers loadbalancers)))

(When #"^we run puppet with '([a-z]+\.pp)'$" [manifest]
  (def command (sh "./run-puppet.sh" manifest))
  (assert (= 0 (:exit command))))

(When #"^after (\d+) seconds$" [seconds]
  (Thread/sleep (* 1000 (parse-int seconds))))
