package puppetlabs_aws_expect;

import expectations.junit.ExpectationsTestRunner;
import org.junit.runner.RunWith;

@RunWith(ExpectationsTestRunner.class)
public class AllExpectationsTest implements ExpectationsTestRunner.TestSource{
  public String testPath() {
    return "test/clojure/puppetlabs_aws_expect";
  }
}
