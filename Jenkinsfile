pipeline {
    agent {
        label 'master'
    }
    stages {
        agent { dockerfile true }
        stage('Test') {
            steps {
                sh "bundle install"
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
