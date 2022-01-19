start:
	(cd front && npm start)

deploy:
	(cd front && npm run deploy)

lambda:
	(cd back && terraform apply -auto-approve)
