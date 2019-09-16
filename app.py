from flask import Flask, jsonify, abort, make_response
from flask import request

app = Flask(__name__)

matches = [
    {
        'id': 1,
        'title': 'Brian Wan d. Michael Choi.',
        'score': '6-3, 6-3'
    },
    {
        'id': 2,
        'title': 'Douglas Lin d. Michael Choi',
        'score': '7-5, 6-3'
    }
]


@app.route('/urating/api/v1.0/matches', methods=['GET'])
def get_tasks():
    return jsonify({'matches': matches})


@app.route('/urating/api/v1.0/matches/<int:match_id>', methods=['GET'])
def get_task(match_id):
    match = [match for match in matches if match['id'] == match_id]
    if len(match) == 0:
        abort(404)
    return jsonify({'match': match[0]})


@app.route('/urating/api/v1.0/matches', methods=['POST'])
def create_match():
    if not request.json or not 'title' in request.json:
        abort(400)
    match = {
        'id': matches[-1]['id'] + 1,
        'title': request.json['title'],
        'score': request.json.get('score', "")
    }
    matches.append(match)
    return jsonify({'match': match}), 201


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


@app.route('/')
def index():
    return "Welcome to URating!"


@app.errorhandler(404)
def not_found(error):
    return make_response(jsonify({'error': 'Not found'}), 404)


if __name__ == '__main__':
    app.run(debug=True)
