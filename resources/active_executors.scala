import org.apache.spark.SparkContext

def currentActiveExecutors(sc: SparkContext): Seq[String] = {
 val allExecutors = sc.getExecutorMemoryStatus.map(_._1)
 val driverAddress = org.apache.spark.SparkEnv.get.blockManager.blockManagerId.hostPort
 allExecutors.filter(_ != driverAddress).toList
}

// Executors register a moment after the shell starts; give them up to 60s.
var waited = 0
while (currentActiveExecutors(sc).size < 3 && waited < 60) {
  Thread.sleep(1000)
  waited += 1
}

println("ACTIVE EXECUTORS: " + currentActiveExecutors(sc).size)
