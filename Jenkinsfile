pipeline {
    agent {
        label 'master'
    }
    stages {
        stage('Test') {
            agent { dockerfile true }
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
