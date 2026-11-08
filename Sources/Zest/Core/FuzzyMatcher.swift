import Foundation

/// High-performance, zero-allocation subsequence fuzzy matcher for fast keyboard filtering.
public enum FuzzyMatcher: Sendable {
    
    /// Evaluates whether `query` is a subsequence of `target` (case-insensitive) and computes a relevance score.
    /// Higher score indicates a better, tighter match.
    public static func match(query: String, in target: String) -> (matched: Bool, score: Int) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return (true, 0)
        }
        
        let targetChars = Array(target)
        let queryChars = Array(q)
        
        if queryChars.count > targetChars.count {
            return (false, 0)
        }
        
        var queryIdx = 0
        var score = 0
        var consecutiveMatches = 0
        var prevMatchTargetIdx = -1
        
        for (tIdx, tChar) in targetChars.enumerated() {
            guard queryIdx < queryChars.count else { break }
            
            let qChar = queryChars[queryIdx]
            let isMatch = tChar.lowercased() == qChar.lowercased()
            
            if isMatch {
                // Base match reward
                score += 10
                
                // Start-of-string bonus
                if tIdx == 0 {
                    score += 25
                }
                
                // Word boundary bonus (after space, underscore, dash, dot, colon, slash)
                if tIdx > 0 {
                    let prevChar = targetChars[tIdx - 1]
                    if prevChar == " " || prevChar == "_" || prevChar == "-" || prevChar == "." || prevChar == "/" || prevChar == ":" {
                        score += 20
                    } else if prevChar.isLowercase && tChar.isUppercase {
                        // CamelCase boundary bonus
                        score += 15
                    }
                }
                
                // Consecutive character match bonus
                if prevMatchTargetIdx == tIdx - 1 {
                    consecutiveMatches += 1
                    score += 15 * consecutiveMatches
                } else {
                    consecutiveMatches = 0
                    if prevMatchTargetIdx != -1 {
                        // Penalize long distance jumps between matched characters
                        let gap = tIdx - prevMatchTargetIdx - 1
                        score -= min(gap * 2, 20)
                    }
                }
                
                prevMatchTargetIdx = tIdx
                queryIdx += 1
            }
        }
        
        let allMatched = queryIdx == queryChars.count
        return (allMatched, allMatched ? max(score, 1) : 0)
    }
}
