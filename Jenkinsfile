pipeline {
    agent none
    stages {
        stage('Test') {
            agent {
                dockerfile {
                    args '-u root:root'
                }
            }
            steps {
                sh "bundle install"
                sh "if [ -f bin/run-csvw-tests ]; then rm bin/run-csvw-tests; fi"
                sh "if [ -f features/csvw_validation_tests.feature ]; then rm features/csvw_validation_tests.feature; fi"
                sh "if [ -d features/fixtures/csvw ]; then rm -Rf features/fixtures/csvw; fi"
                sh "ruby features/support/load_tests.rb"
                sh "rake"
                sh "bundle exec cucumber -f junit -o test-results"
            }
        }
    }
    post {
        always {
            script {
                node {
                    junit allowEmptyResults: true, testResults: 'test-results/*.xml'
                }
            }
        }
    }
}
