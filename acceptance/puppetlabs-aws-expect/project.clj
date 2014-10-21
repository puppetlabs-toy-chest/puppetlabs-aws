(defproject puppetlabs-aws-expect "0.1.0-SNAPSHOT"
  :description "Experiments writing tests against an IaaS provider"
  :url "https://github.com/puppetlabs/puppetlabs-aws"
  :license {:name "Eclipse Public License"
            :url "http://www.eclipse.org/legal/epl-v10.html"}
  :plugins [
            [lein-kibit "0.0.8"]
            [jonase/eastwood "0.1.4"]
            [lein-cucumber "1.0.2"]]
  :aliases {"test" ["cucumber"]}
  :dependencies [
                 [org.clojure/clojure "1.5.1"]
                 [environ "0.5.0"]
                 [clj-time "0.8.0"]
                 [com.brainbot/iniconfig "0.2.0"]
                 [amazonica "0.2.24" :exclusions [joda-time]]])
