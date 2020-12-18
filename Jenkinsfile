pipeline {
    agent {
        label 'master'
    }
    stages {
        stage('Test') {
            agent {
                dockerfile {
                    args '-u root:root'
                }
            }
            steps {
                sh "bundle install"
                sh "rake"
                sh "bundle exec cucumber -f junit -o test-results"
            }
        }
    }
    post {
        always {
            script {
                junit allowEmptyResults: true, testResults: 'test-results/*.xml'
            }
        }
    }
}
