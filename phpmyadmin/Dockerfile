FROM phpmyadmin:latest

COPY ponto-de-entrada.sh /ponto-de-entrada.sh
RUN chmod +x /ponto-de-entrada.sh

ENTRYPOINT ["/ponto-de-entrada.sh"]
CMD ["apache2-foreground"]