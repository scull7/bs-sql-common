let connect = () =>
  MySql2.connect(~host="127.0.0.1", ~port=3306, ~user="root", ());
