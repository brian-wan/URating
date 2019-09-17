import React, { Component } from 'react';
import Match from './Match.js';

export default class Table extends Component {

    render() {
        if (this.props.matchList[0] === undefined)
            return null;

        return (
            <div>
                <Match matchID = {this.props.matchList[0].id} matchScore = {this.props.matchList[0].score} matchTitle = {this.props.matchList[0].title}>
                </Match>
                <Match matchID = {this.props.matchList[1].id} matchScore = {this.props.matchList[1].score} matchTitle = {this.props.matchList[1].title}>
                </Match>
            </div>
        )
    }
}
