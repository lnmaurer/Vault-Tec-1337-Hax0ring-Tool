#!/usr/bin/ruby

#Vault-Tec 1337 Hax0ring Tool -- a program to aid hacking in Fallout 3
#Copyright (C) 2008  Leon N. Maurer

#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#version 2 as published by the Free Software Foundation;

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#A copy of the license is available at 
#<http://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
#You can also receive a paper copy by writing the Free Software
#Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


require 'tk'

def lettersInCommon(word1, word2)
  word1.split(//).zip(word2.split(//)).inject(0){|sum,c| sum + (c[0] == c[1] ? 1 : 0)}
end

class WordLenghtError < ArgumentError
end

class SpellingError < ArgumentError
end

class WordCracker
  attr_reader :words

  def initialize(words = Array.new)
    @words = words
    #check word length?
  end
  def wordLength
    @words[0].length
  end
  def rightLength(word)
    (@words.size == 0) or (self.wordLength == word.length)
  end
  def add(word)
  #TODO: raise an exception?
    if rightLength(word) # and @wordList.include?(word)
      @words << word
    else
      raise WordLenghtError, "Wrong word length"
    end
  end
  def remove(word)
    @words.delete(word)
  end
  def tried(wrongword, correct)
    @words.reject!{|word| (word == wrongword) or (lettersInCommon(word,wrongword) != correct)}
  end
  def suggestWords
    #makes an maxtrix where element i,j is how many letters are in common between word i and word j
    commonMatrix = @words.collect{|word1|
      @words.collect{|word2|
        lettersInCommon(word1,word2)
      }
    }
    #calculate the expected value for how many words will be left after
    #choosing a word, there is one element for each word, and they're in the
    #same order as in @words
    expectedkeep = commonMatrix.collect{|arr|
      #this array will have element n be the number of works that have n
      #letters in common with the word in question
      types = Array.new(self.wordLength,0)
      #don't want to compare word to iteself, so igonre the case when all the
      #letters are in common
      arr.each{|val| types[val] += 1 unless val == self.wordLength}
      #to calculate the expected value for a given word:
      #Pn will be the probability that the word has n correct letters, and Nn
      #will be the number of other words that have n letters in common with our
      #given word. So, for our given word,
      #our expected value = P0*N0 + P1*N1 + P2*N2 + P3*N3 + ...
      #Now, Pn = Nn/(# of oterh words) since each word is equally likely to be
      #the correct word. So, the expected value boils down to:
      #(N0^2 + N1^2 + N3^2 + ...)/(# of other words)
      expectedKeep = types.inject(0.0){|p,num| p + num**2/(@words.size - 1.0)}
    }
    #put words and their expected values together, then sort by the expected keep
    @words.zip(expectedkeep).sort_by{|word,keep| keep}
  end

end

class HackerInterface
  def initialize
    @root = TkRoot.new(){title 'VLHT'}
    @hacker = WordCracker.new

    #first, the word list
    yscroll = proc{|*args| @lbscroll.set(*args)}
    scroll = proc{|*args| @list.yview(*args)}
    @words = TkVariable.new
    @list = TkListbox.new(@root){
      yscrollcommand yscroll
      height 10
    }.grid(:column=>0,:row=>0,:columnspan=>3,:sticky=>'nsew')
    @list.listvariable(@words)
    #the scroll bar that goes with it
    @lbscroll = TkScrollbar.new(@root) {
      orient 'vertical'
      command scroll
    }.grid(:column=>4,:row=>0,:sticky=>'wns')

    #the next row is for adding words
    @wordEntry = TkVariable.new
    add = proc{
      begin
        @hacker.add(@wordEntry.value.to_s.upcase)
        @wordEntry.value = ''
        self.updateList
      rescue WordLenghtError
        Tk.messageBox(
          :type=>'ok',
          :icon=>'error',
          :title=>'Wrong Word Length',
          :message=>'The word you entered is not the same length as the other word(s) in the list.')
      end
    }
    TkLabel.new(@root){
      text 'Word:'
    }.grid('column'=>0, 'row'=>1,'sticky'=>'wns')
    wordEntryBox = TkEntry.new(@root) {
      width 15
      relief  'sunken'
    }.grid(:column=>1,:row=> 1,:sticky=>'w')
    wordEntryBox.textvariable(@wordEntry)
    wordEntryBox.bind("Any-Key-Return"){add.call}
    TkButton.new(@root) {
      text    'Add'
      command add
    }.grid(:column=>2,:row=>1)

    #the next line is for updating words
    update = proc{
      @hacker.tried(self.selectedWord,@correctLetters.value.to_i)
      @correctLetters.value = ''
      self.updateList
    }
    TkLabel.new(@root){
      text 'Correct:'
    }.grid(:column=>0,:row=>2,:sticky=>'wns')
    @correctLetters = TkVariable.new()
    correctLettersBox = TkEntry.new(@root) {
      width 15
      relief  'sunken'
    }.grid(:column=>1,:row=> 2,:sticky=>'w')
    correctLettersBox.textvariable(@correctLetters)
    correctLettersBox.bind("Any-Key-Return"){update.call}
    TkButton.new(@root) {
      text    'Update'
      command update
    }.grid(:column=>2,:row=>2)

    #and the final line only has a delete button
    remove = proc{
      @hacker.remove(self.selectedWord)
      self.updateList
    }
    TkButton.new(@root) {
      text    'Remove'
      command remove
    }.grid(:column=>2,:row=>3)

  end
  def updateList
    suggestion = @hacker.suggestWords
    @wordList = suggestion.collect{|word,left| word}
    if @hacker.words.size == 0
      @words.value = ['']
    else
      @words.value = suggestion.collect{|word,left| "#{word} #{left}"}
    end
  end
  def selectedWord
    #there should be a cleaner way to do the following line
    @wordList[@list.curselection[0].to_i]
  end
end

if __FILE__ == $0
  HackerInterface.new
  Tk.mainloop()
end