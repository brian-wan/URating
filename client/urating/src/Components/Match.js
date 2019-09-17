import React, { Component } from 'react'

export default class Match extends Component {
    render() {
        return (
            <div>
                <p>{this.props.matchTitle}</p>
                <p>{this.props.matchScore}</p>
            </div>
        )
    }
}
