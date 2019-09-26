>>> db.create_all()
>>> player1 = Player(username="Brian", password = "Brian")
>>> player2 = Player(username="Alex", password = "Alex")
>>> db.session.add(player1)
>>> db.session.add(player2)
>>> db.session.commit()
>>> Player.query.all()
[User('Brian', '1', '[]'), User('Alex', '2', '[]')]
>>> player1 = Player.query.first()
>>> player1.id
1
>>> player1.username
'Brian'
>>> player1.password
'Brian'
>>> player1.matches
[]
>>> match1 = Match(title='Alex d. Brian', score='6-4, 6-4', winner='Alex', loser='Brian')
>>> Player.query.filter_by(username=match1.winner).first().matches.append(match1)
>>> Player.query.filter_by(username=match1.loser).first().matches.append(match1)
>>> db.session.add(match1)
>>> db.session.commit()
>>> match1.title
'Alex d. Brian'
>>> match1.score
'6-4, 6-4'
>>> match1.players.all()
[User('Alex', '2', '[('Alex d. Brian', '6-4, 6-4', '2019-09-26 04:27:54.622280', 'Alex', 'Brian')]')]
>>> player1 = match1.players[0]
>>> player1
User('Alex', '2', '[('Alex d. Brian', '6-4, 6-4', '2019-09-26 04:27:54.622280', 'Alex', 'Brian')]')
>>> player1.matches
[('Alex d. Brian', '6-4, 6-4', '2019-09-26 04:27:54.622280', 'Alex', 'Brian')]
