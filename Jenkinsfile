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
                sh "rm bin/run-csvw-tests"
                sh "rm features/csvw_validation_tests.feature"
                sh "rm -r features/fixtures/csvw"
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