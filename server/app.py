from flask import Flask, jsonify, abort, make_response
from flask import request
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime


app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///site.db'
db = SQLAlchemy(app)

# database stuff
player_matches = db.Table('player_matches',
                          db.Column('player_id', db.Integer,
                                    db.ForeignKey('player.id')),
                          db.Column('match_id', db.Integer,
                                    db.ForeignKey('match.id'))
                          )


class Player(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(20), nullable=False, unique=True)
    password = db.Column(db.String(20), nullable=False)
    matches = db.relationship(
        'Match', secondary='player_matches', backref=db.backref('players', lazy='dynamic'))

    def __repr__(self):
        return f"User('{self.username}', '{self.matches}')"


class Match(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(30), nullable=False)
    score = db.Column(db.String(20), nullable=False)
    date_posted = db.Column(db.DateTime,
                            default=datetime.utcnow)
    winner = db.Column(db.String(20), nullable=False)
    loser = db.Column(db.String(20), nullable=False)

    def __repr__(self):
        return f"('{self.title}')"


# routes

@app.route('/urating/api/v1.0/matches', methods=['GET'])
def get_matches():
    # returns json with key-values for each match json
    matches_json = {}
    for match in Match.query.all():
        match_json = {
            'title': match.title,
            'score': match.score,
            'winner': match.winner,
            'loser': match.loser,
            'date_posted': match.date_posted
        }
        matches_json[match.title] = match_json
    return jsonify({'matches': matches_json})


@app.route('/urating/api/v1.0/matches/<int:match_id>', methods=['GET'])
def get_match(match_id):
    # returns json of single match
    match = Match.query.get(match_id)
    match_json = {
        'title': match.title,
        'score': match.score,
        'winner': match.winner,
        'loser': match.loser,
        'date_posted': match.date_posted
    }
    return jsonify({'match': match_json})


@app.route('/urating/api/v1.0/create_match', methods=['POST'])
def create_match():
    # changed route to create match from matches
    title = request.args.get('title')
    score = request.args.get('score')
    winner = request.args.get('winner')
    loser = request.args.get('loser')
    match = Match(title=title, score=score,
                  winner=winner, loser=loser)
    # add match to both players who played
    player1 = Player.query.filter_by(username=winner).first()
    player1.matches.append(match)
    player2 = Player.query.filter_by(username=loser).first()
    player2.matches.append(match)
    # add match
    db.session.add(match)
    db.session.commit()


@app.route('/urating/api/v1.0/create_player', methods=['POST'])
def create_player():
    # create a new player account
    username = request.args.get('username')
    password = request.args.get('password')
    player = Player(username=username, password=password)
    # add player
    db.session.add(player)
    db.session.commit()


# not done yet
"""
@app.route('/urating/api/v1.0/matches/<int:match_id>', methods=['PUT'])
def update_match(match_id):
    match = [match for match in matches if match['id'] == match_id]
    if len(match) == 0:
        abort(404)
    if not request.json:
        abort(400)
    if 'title' in request.json and type(request.json['title']) != unicode:
        abort(400)
    if 'score' in request.json and type(request.json['score']) is not unicode:
        abort(400)
    match[0]['title'] = request.json.get('title', match[0]['title'])
    match[0]['score'] = request.json.get(
        'score', task[0]['score'])
    return jsonify({'match': match[0]})


@app.route('/urating/api/v1.0/matches/<int:match_id>', methods=['DELETE'])
def delete_match(match_id):
    match = [match for match in matches if match['id'] == match_id]
    if len(match) == 0:
        abort(404)
    matches.remove(match[0])
    return jsonify({'result': True})
"""


@app.route('/')
def index():
    return "Welcome to URating!"


@app.errorhandler(404)
def not_found(error):
    return make_response(jsonify({'error': 'Not found'}), 404)


if __name__ == '__main__':
    app.run(debug=True)
